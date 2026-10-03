import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/payments/domain/payment.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/sales/data/return_service.dart';
import 'package:qubexcore_pos/features/sales/domain/sale_return.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ProductRepository products;
  late CustomerRepository customers;
  late CheckoutService checkout;
  late ReturnService returns;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    products = ProductRepository(db);
    customers = CustomerRepository(db);
    checkout = CheckoutService(db);
    returns = ReturnService(db);
    await SettingsRepository(db).ensureSeededDefaults();
  });

  tearDown(() async {
    await db.close();
  });

  Future<(CheckoutOutcome, int)> saleOf({
    double quantity = 2,
    String paymentMethod = PaymentMethods.cash,
    String? customerUuid,
  }) async {
    final product = (await products.create(
      name: 'Espresso',
      sellingPriceMinor: 1200,
      stockQuantity: 10,
    ))
        .dataOrNull!;
    final result = await checkout.completeSale(
      CheckoutRequest(
        items: [CartItem.fromProduct(product, quantity: quantity)],
        paymentMethod: paymentMethod,
        cashReceivedMinor: 10000,
        customerUuid: customerUuid,
      ),
    );
    final outcome = result.dataOrNull!;
    return (outcome, product.id!);
  }

  Future<double> stockOf(int productId) async {
    final row = (await db.db.query(
      'products',
      columns: ['stock_quantity'],
      where: 'id = ?',
      whereArgs: [productId],
    ))
        .single;
    return (row['stock_quantity'] as num).toDouble();
  }

  test('return restores stock, writes movement rows, and records refund',
      () async {
    final (outcome, productId) = await saleOf();
    expect(await stockOf(productId), 8.0); // 10 - 2

    final result = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 1,
        ),
      ],
    );

    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    final saleReturn = result.dataOrNull!;
    expect(saleReturn.refundTotalMinor, 1200);
    expect(await stockOf(productId), 9.0);

    final movement = (await db.db.query(
      'stock_movements',
      where: 'movement_type = ?',
      whereArgs: ['sale_return'],
    ))
        .single;
    expect(movement['quantity_change'], 1.0);
    expect(movement['quantity_after'], 9.0);
    expect(movement['reference_id'], saleReturn.uuid);

    final items = await db.db.query('return_items');
    expect(items, hasLength(1));
    expect(items.single['line_refund_minor'], 1200);
    expect(items.single['product_name'], 'Espresso');
  });

  test('returning more than the sold quantity is rejected', () async {
    final (outcome, productId) = await saleOf(quantity: 2);

    final result = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 3,
        ),
      ],
    );

    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull!.code, 'exceeds_returnable');
    expect(await db.db.query('returns'), isEmpty);
    expect(await db.db.query('return_items'), isEmpty);
    expect(await stockOf(productId), 8.0);
  });

  test('prior returns reduce the returnable quantity', () async {
    final (outcome, productId) = await saleOf(quantity: 2);
    final first = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 1,
        ),
      ],
    );
    expect(first.isSuccess, isTrue);
    expect(await stockOf(productId), 9.0);

    final second = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 2,
        ),
      ],
    );
    expect(second.isSuccess, isFalse);
    expect(second.failureOrNull!.code, 'exceeds_returnable');
    expect(await stockOf(productId), 9.0);
    expect(await db.db.query('returns'), hasLength(1));
  });

  test('one invalid line rolls back the whole return', () async {
    final (outcome, productId) = await saleOf(quantity: 2);

    final result = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 1,
        ),
        // Belongs to no sale: validation fails after the first line.
        const ReturnLineInput(saleItemId: 999999, quantity: 1),
      ],
    );

    expect(result.isSuccess, isFalse);
    expect(result.failureOrNull!.code, 'invalid_line');
    // Nothing was written: no return rows, stock untouched, no movement.
    expect(await db.db.query('returns'), isEmpty);
    expect(await db.db.query('return_items'), isEmpty);
    expect(await stockOf(productId), 8.0);
    expect(
      await db.db.query(
        'stock_movements',
        where: 'movement_type = ?',
        whereArgs: ['sale_return'],
      ),
      isEmpty,
    );
  });

  test('credit sale return writes return_credit ledger and reduces balance',
      () async {
    final customer = (await customers.create(
      name: 'Nimal',
      creditLimitMinor: 50000,
    ))
        .dataOrNull!;
    final (outcome, productId) = await saleOf(
      paymentMethod: PaymentMethods.credit,
      customerUuid: customer.uuid,
    );
    final balanceBefore = (await db.db.query(
      'customers',
      where: 'uuid = ?',
      whereArgs: [customer.uuid],
    ))
        .single['balance_minor'] as int;
    expect(balanceBefore, 2400);

    final result = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 1,
        ),
      ],
      reason: 'Damaged',
    );

    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    expect(result.dataOrNull!.refundTotalMinor, 1200);
    expect(await stockOf(productId), 9.0);

    final entry = (await db.db.query(
      'customer_ledger',
      where: 'entry_type = ?',
      whereArgs: ['return_credit'],
    ))
        .single;
    expect(entry['amount_minor'], -1200);
    expect(entry['balance_after_minor'], 1200);
    expect(entry['sale_uuid'], outcome.sale.uuid);

    final balanceAfter = (await db.db.query(
      'customers',
      where: 'uuid = ?',
      whereArgs: [customer.uuid],
    ))
        .single['balance_minor'] as int;
    expect(balanceAfter, 1200);
  });

  test('validation failures: empty lines, bad quantity, unknown sale',
      () async {
    final (outcome, _) = await saleOf();

    final empty =
        await returns.createReturn(saleId: outcome.sale.id!, lines: []);
    expect(empty.failureOrNull!.code, 'validation');

    final badQty = await returns.createReturn(
      saleId: outcome.sale.id!,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 0,
        ),
      ],
    );
    expect(badQty.failureOrNull!.code, 'validation');

    final missing = await returns.createReturn(
      saleId: 999999,
      lines: [
        ReturnLineInput(
          saleItemId: outcome.items.single.id!,
          quantity: 1,
        ),
      ],
    );
    expect(missing.failureOrNull!.code, 'not_found');
    expect(await db.db.query('returns'), isEmpty);
  });
}
