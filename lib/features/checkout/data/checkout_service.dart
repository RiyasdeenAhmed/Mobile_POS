import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/tax_calculator.dart';
import '../../../core/utils/time_utils.dart';
import '../../customers/domain/customer.dart';
import '../../payments/domain/payment.dart';
import '../../pos/domain/cart_item.dart';
import '../../products/domain/product.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../domain/checkout_models.dart';

class _CheckoutException implements Exception {
  final String message;
  final String code;

  _CheckoutException(this.message, this.code);

  @override
  String toString() => 'CheckoutException($code): $message';
}

class CheckoutService {
  final AppDatabase database;

  CheckoutService(this.database);

  Future<AppResult<CheckoutOutcome>> completeSale(
    CheckoutRequest request,
  ) async {
    final validationError = _validateRequest(request);
    if (validationError != null) {
      return failure(validationError.message, code: validationError.code);
    }

    final items = List<CartItem>.of(request.items);
    final method = request.paymentMethod;
    final now = utcNowIso();
    final saleUuid = request.saleUuid ?? newBusinessId();

    final existing = await _findSaleByUuid(saleUuid);
    if (existing != null && existing.id != null) {
      final existingItems = await _listItems(existing.id!);
      final existingPayment = await _listPaymentsBySaleId(existing.id!);
      return success(
        CheckoutOutcome(
          sale: existing,
          items: existingItems,
          payments: existingPayment,
          changeMinor: existing.changeMinor,
        ),
      );
    }

    try {
      final outcome = await database.db.transaction<CheckoutOutcome>(
        (txn) async {
          var subtotalMinor = 0;
          var discountMinor = 0;
          for (final item in items) {
            if (item.quantity <= 0) {
              throw _CheckoutException(
                'Quantity must be greater than zero',
                'validation',
              );
            }
            if (item.lineTotalMinor < 0) {
              throw _CheckoutException(
                'Line total cannot be negative',
                'validation',
              );
            }
            subtotalMinor += item.lineGrossMinor;
            discountMinor += item.discountMinor;
          }
          final taxableMinor = subtotalMinor - discountMinor;
          final taxRateBps =
              int.tryParse(await _readSetting(txn, 'tax_rate_bps') ?? '') ?? 0;
          final taxMinor = TaxCalculator.taxMinor(taxableMinor, taxRateBps);
          final totalMinor = taxableMinor + taxMinor;

          int amountPaidMinor;
          int changeMinor;
          int amountDueMinor;
          String? cardReference;
          Customer? customer;

          switch (method) {
            case PaymentMethods.cash:
              if (request.cashReceivedMinor < totalMinor) {
                throw _CheckoutException(
                  'Cash received is less than the total',
                  'insufficient_cash',
                );
              }
              amountPaidMinor = totalMinor;
              changeMinor = request.cashReceivedMinor - totalMinor;
              amountDueMinor = 0;
            case PaymentMethods.creditCard:
            case PaymentMethods.debitCard:
            case PaymentMethods.qr:
            case PaymentMethods.card:
              amountPaidMinor = totalMinor;
              changeMinor = 0;
              amountDueMinor = 0;
              cardReference = request.cardReference?.trim();
              if (cardReference != null && cardReference.isEmpty) {
                cardReference = null;
              }
            case PaymentMethods.split:
              final allocations = request.allocations;
              if (allocations.length < 2 ||
                  allocations.map((a) => a.method).toSet().length !=
                      allocations.length ||
                  allocations.any((a) =>
                      !PaymentMethods.paid.contains(a.method) ||
                      a.amountMinor <= 0) ||
                  allocations.fold<int>(0, (sum, a) => sum + a.amountMinor) !=
                      totalMinor) {
                throw _CheckoutException(
                    'Split payments must use distinct paid methods and total the bill exactly',
                    'invalid_split');
              }
              changeMinor = 0;
              for (final a in allocations) {
                if (a.method == PaymentMethods.cash) {
                  if ((a.receivedMinor ?? 0) < a.amountMinor) {
                    throw _CheckoutException(
                        'Cash received is less than the cash allocation',
                        'insufficient_cash');
                  }
                  changeMinor += a.receivedMinor! - a.amountMinor;
                }
              }
              amountPaidMinor = totalMinor;
              amountDueMinor = 0;
            case PaymentMethods.credit:
              final customerUuid = request.customerUuid;
              if (customerUuid == null || customerUuid.trim().isEmpty) {
                throw _CheckoutException(
                  'A customer is required for credit sales',
                  'credit_requires_customer',
                );
              }
              customer = await _loadCustomerForCredit(txn, customerUuid.trim());
              amountPaidMinor = 0;
              changeMinor = 0;
              amountDueMinor = totalMinor;
            default:
              throw _CheckoutException(
                'Unsupported payment method',
                'validation',
              );
          }

          if (request.customerUuid != null &&
              request.customerUuid!.trim().isNotEmpty &&
              customer == null &&
              method != PaymentMethods.credit) {
            customer =
                await _loadCustomerOptional(txn, request.customerUuid!.trim());
          }

          final customerId = customer?.id;

          await txn.insert(
            'sales',
            {
              'uuid': saleUuid,
              'invoice_number': '',
              'sale_at': now,
              'customer_id': customerId,
              'staff_uuid': request.staffUuid,
              'subtotal_minor': subtotalMinor,
              'discount_minor': discountMinor,
              'tax_minor': taxMinor,
              'total_minor': totalMinor,
              'amount_paid_minor': amountPaidMinor,
              'change_minor': changeMinor,
              'amount_due_minor': amountDueMinor,
              'status': 'completed',
              'payment_method': method,
              'notes': request.notes,
              'created_at': now,
              'updated_at': now,
            },
          );

          final saleIdRows = await txn.query(
            'sales',
            columns: ['id'],
            where: 'uuid = ?',
            whereArgs: [saleUuid],
            limit: 1,
          );
          if (saleIdRows.isEmpty) {
            throw _CheckoutException(
              'Unable to resolve completed sale',
              'database',
            );
          }
          final saleId = saleIdRows.first['id'] as int;

          final invoiceNumber = await _reserveInvoiceNumber(txn, now);
          await txn.update(
            'sales',
            {
              'invoice_number': invoiceNumber,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [saleId],
          );

          final itemIds = <SaleItem>[];
          for (final item in items) {
            final product = await _loadProductForSale(txn, item.productUuid);
            if (product.trackStock) {
              final available = product.stockQuantity;
              if (available < item.quantity) {
                throw _CheckoutException(
                  'Insufficient stock for ${product.name}',
                  'insufficient_stock',
                );
              }
              final quantityAfter = available - item.quantity;
              await txn.update(
                'products',
                {
                  'stock_quantity': quantityAfter,
                  'updated_at': now,
                },
                where: 'id = ?',
                whereArgs: [product.id],
              );
              await txn.insert(
                'stock_movements',
                {
                  'uuid': newBusinessId(),
                  'product_id': product.id,
                  'movement_type': 'sale',
                  'quantity_change': -item.quantity,
                  'quantity_after': quantityAfter,
                  'reference_type': 'sale',
                  'reference_id': saleUuid,
                  'note': null,
                  'staff_uuid': request.staffUuid,
                  'created_at': now,
                },
              );
            }

            final saleItem = SaleItem(
              uuid: newBusinessId(),
              saleId: saleId,
              productId: product.id!,
              productUuid: product.uuid,
              productName: product.name,
              productSku: product.sku,
              productBarcode: product.barcode,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              unitCostMinor: item.unitCostMinor,
              discountMinor: item.discountMinor,
              lineTotalMinor: item.lineTotalMinor,
              currency: item.currency,
              createdAt: now,
            );
            final saleItemId = await txn.insert(
              'sale_items',
              saleItem.toMap()..remove('id'),
            );
            itemIds.add(saleItem.copyWith(id: saleItemId));
          }

          final allocations = method == PaymentMethods.split
              ? request.allocations
              : [
                  PaymentAllocation(
                      method: method,
                      amountMinor: method == PaymentMethods.credit
                          ? amountDueMinor
                          : amountPaidMinor,
                      receivedMinor: method == PaymentMethods.cash
                          ? request.cashReceivedMinor
                          : null,
                      reference: cardReference)
                ];
          final payments = <Payment>[];
          for (final allocation in allocations) {
            final payment = Payment(
              uuid: newBusinessId(),
              saleId: saleId,
              paymentMethod: allocation.method,
              amountMinor: allocation.amountMinor,
              reference: allocation.reference?.trim(),
              receivedMinor: allocation.method == PaymentMethods.cash
                  ? allocation.receivedMinor
                  : null,
              changeMinor: allocation.method == PaymentMethods.cash
                  ? allocation.receivedMinor! - allocation.amountMinor
                  : null,
              paidAt: now,
              staffUuid: request.staffUuid,
              createdAt: now,
            );
            await txn.insert('payments', payment.toMap()..remove('id'));
            payments.add(payment);
          }

          if (method == PaymentMethods.credit && customer != null) {
            final newBalance = customer.balanceMinor + amountDueMinor;
            if (customer.creditLimitMinor <= 0 || !customer.creditEnabled) {
              throw _CheckoutException(
                'Customer has no credit facility',
                'credit_limit_exceeded',
              );
            }
            if (newBalance > customer.creditLimitMinor) {
              throw _CheckoutException(
                'Credit limit exceeded',
                'credit_limit_exceeded',
              );
            }
            await txn.update(
              'customers',
              {
                'balance_minor': newBalance,
                'updated_at': now,
              },
              where: 'id = ?',
              whereArgs: [customer.id],
            );
            await txn.insert(
              'customer_ledger',
              {
                'uuid': newBusinessId(),
                'customer_id': customer.id,
                'entry_type': 'debt_sale',
                'amount_minor': amountDueMinor,
                'balance_after_minor': newBalance,
                'sale_uuid': saleUuid,
                'sale_id': saleId,
                'note': null,
                'staff_uuid': request.staffUuid,
                'created_at': now,
              },
            );
          }

          final saleRows = await txn.query(
            'sales',
            where: 'id = ?',
            whereArgs: [saleId],
            limit: 1,
          );
          if (saleRows.isEmpty) {
            throw _CheckoutException(
              'Unable to load completed sale',
              'database',
            );
          }

          return CheckoutOutcome(
            sale: Sale.fromMap(saleRows.first),
            items: itemIds,
            payments: payments,
            changeMinor: changeMinor,
          );
        },
      );
      database.financialChanged();
      return success(outcome);
    } on _CheckoutException catch (e) {
      return failure(e.message, code: e.code);
    } on DatabaseException catch (e) {
      final message = describeDatabaseError(e, 'Unable to complete sale');
      if (message.contains('sales.uuid') ||
          message.contains('UNIQUE constraint failed: sales.uuid')) {
        final existingSale = await _findSaleByUuid(saleUuid);
        if (existingSale != null && existingSale.id != null) {
          final existingItems = await _listItems(existingSale.id!);
          final existingPayment = await _listPaymentsBySaleId(existingSale.id!);
          return success(
            CheckoutOutcome(
              sale: existingSale,
              items: existingItems,
              payments: existingPayment,
              changeMinor: existingSale.changeMinor,
            ),
          );
        }
      }
      return failure(message, code: 'database');
    } catch (e) {
      return failure(
        describeDatabaseError(e, 'Unable to complete sale'),
        code: 'database',
      );
    }
  }

  _CheckoutException? _validateRequest(CheckoutRequest request) {
    if (request.items.isEmpty) {
      return _CheckoutException('Cart is empty', 'empty_cart');
    }
    for (final item in request.items) {
      if (item.productUuid.trim().isEmpty) {
        return _CheckoutException(
            'Cart item is missing a product', 'validation');
      }
      if (item.quantity <= 0) {
        return _CheckoutException(
          'Quantity must be greater than zero',
          'validation',
        );
      }
      if (item.unitPriceMinor < 0 || item.unitCostMinor < 0) {
        return _CheckoutException(
          'Product prices cannot be negative',
          'validation',
        );
      }
      if (item.discountMinor < 0) {
        return _CheckoutException(
          'Discount cannot be negative',
          'validation',
        );
      }
      if (item.lineTotalMinor < 0) {
        return _CheckoutException(
          'Line total cannot be negative',
          'validation',
        );
      }
    }
    if (!PaymentMethods.all.contains(request.paymentMethod)) {
      return _CheckoutException('Unsupported payment method', 'validation');
    }
    return null;
  }

  Future<String> _reserveInvoiceNumber(DatabaseExecutor txn, String now) async {
    final rows = await txn.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['invoice_sequence'],
      limit: 1,
    );
    var sequence = 0;
    if (rows.isNotEmpty) {
      sequence = int.tryParse('${rows.first['value']}') ?? 0;
    }
    sequence += 1;
    await txn.insert(
      'app_settings',
      {
        'key': 'invoice_sequence',
        'value': '$sequence',
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    var prefix = (await _readSetting(txn, 'invoice_prefix'))?.trim() ?? '';
    if (prefix.isEmpty) prefix = 'INV';
    return '$prefix-${sequence.toString().padLeft(6, '0')}';
  }

  Future<String?> _readSetting(DatabaseExecutor txn, String key) async {
    final rows = await txn.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<Customer> _loadCustomerForCredit(
    DatabaseExecutor txn,
    String customerUuid,
  ) async {
    final rows = await txn.query(
      'customers',
      where: 'uuid = ?',
      whereArgs: [customerUuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw _CheckoutException('Customer not found', 'not_found');
    }
    final customer = Customer.fromMap(rows.first);
    if (!customer.isActive || customer.isArchived) {
      throw _CheckoutException('Customer is not available', 'validation');
    }
    return customer;
  }

  Future<Customer?> _loadCustomerOptional(
    DatabaseExecutor txn,
    String customerUuid,
  ) async {
    final rows = await txn.query(
      'customers',
      where: 'uuid = ?',
      whereArgs: [customerUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<Product> _loadProductForSale(
    DatabaseExecutor txn,
    String productUuid,
  ) async {
    final rows = await txn.query(
      'products',
      where: 'uuid = ?',
      whereArgs: [productUuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw _CheckoutException('Product not found', 'not_found');
    }
    final product = Product.fromMap(rows.first);
    if (!product.isActive || product.isArchived) {
      throw _CheckoutException(
        'Product is unavailable',
        'validation',
      );
    }
    return product;
  }

  Future<Sale?> _findSaleByUuid(String saleUuid) async {
    final rows = await database.db.query(
      'sales',
      where: 'uuid = ?',
      whereArgs: [saleUuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<List<SaleItem>> _listItems(int saleId) async {
    final rows = await database.db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return rows.map(SaleItem.fromMap).toList();
  }

  Future<List<Payment>> _listPaymentsBySaleId(int saleId) async {
    final rows = await database.db.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return rows.map(Payment.fromMap).toList();
  }
}
