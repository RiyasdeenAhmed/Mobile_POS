import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/sale_return.dart';

/// Atomic returns against a completed sale: return rows, stock restore with
/// movements, and — for credit sales — a `return_credit` ledger entry that
/// reduces the customer's debt. Rolls back everything on any failure.
class ReturnService {
  final AppDatabase database;

  ReturnService(this.database);

  Future<AppResult<SaleReturn>> createReturn({
    required int saleId,
    required List<ReturnLineInput> lines,
    String? refundMethod,
    String? reason,
    String? staffUuid,
  }) async {
    if (lines.isEmpty) {
      return failure('Return lines are required', code: 'validation');
    }
    for (final line in lines) {
      if (!(line.quantity > 0)) {
        return failure(
          'Return quantity must be greater than zero',
          code: 'validation',
        );
      }
    }

    final now = utcNowIso();
    try {
      return await database.db.transaction<AppResult<SaleReturn>>((txn) async {
        final saleRows = await txn.query(
          'sales',
          where: 'id = ?',
          whereArgs: [saleId],
          limit: 1,
        );
        if (saleRows.isEmpty) {
          return failure('Sale not found', code: 'not_found');
        }
        final sale = saleRows.first;
        if (sale['status'] != 'completed') {
          return failure(
            'Only completed sales can be returned',
            code: 'not_completed',
          );
        }

        final returnUuid = newBusinessId();
        final resolvedRefundMethod =
            (refundMethod != null && refundMethod.isNotEmpty)
                ? refundMethod
                : sale['payment_method'] as String;

        // Validate every line and compute refunds before writing anything.
        final prepared = <({
          Map<String, Object?> saleItem,
          double quantity,
          int lineRefundMinor,
        })>[];
        for (final line in lines) {
          final itemRows = await txn.query(
            'sale_items',
            where: 'id = ? AND sale_id = ?',
            whereArgs: [line.saleItemId, saleId],
            limit: 1,
          );
          if (itemRows.isEmpty) {
            return failure(
              'Return line does not belong to this sale',
              code: 'invalid_line',
            );
          }
          final item = itemRows.first;
          final sold = (item['quantity'] as num).toDouble();
          final returnedRows = await txn.rawQuery(
            'SELECT COALESCE(SUM(quantity), 0) AS q FROM return_items '
            'WHERE sale_item_id = ?',
            [line.saleItemId],
          );
          final alreadyReturned =
              (returnedRows.first['q'] as num?)?.toDouble() ?? 0;
          final returnable = sold - alreadyReturned;
          if (line.quantity > returnable + 1e-9) {
            return failure(
              'Cannot return more than the sold quantity',
              code: 'exceeds_returnable',
            );
          }
          final unitRefund = item['unit_price_minor'] as int;
          final lineRefund = (unitRefund * line.quantity).round();
          prepared.add((
            saleItem: item,
            quantity: line.quantity,
            lineRefundMinor: lineRefund,
          ));
        }

        final refundTotal =
            prepared.fold<int>(0, (sum, line) => sum + line.lineRefundMinor);

        final returnId = await txn.insert(
          'returns',
          {
            'uuid': returnUuid,
            'sale_id': saleId,
            'sale_uuid': sale['uuid'],
            'customer_id': sale['customer_id'],
            'staff_uuid': staffUuid,
            'status': 'completed',
            'refund_total_minor': refundTotal,
            'refund_method': resolvedRefundMethod,
            'reason': reason,
            'created_at': now,
            'updated_at': now,
          },
        );

        for (final line in prepared) {
          final item = line.saleItem;
          final productId = item['product_id'] as int;
          await txn.insert(
            'return_items',
            {
              'uuid': newBusinessId(),
              'return_id': returnId,
              'sale_item_id': item['id'],
              'product_id': productId,
              'product_uuid': item['product_uuid'],
              'product_name': item['product_name'],
              'quantity': line.quantity,
              'unit_refund_minor': item['unit_price_minor'],
              'line_refund_minor': line.lineRefundMinor,
              'created_at': now,
            },
          );

          // Stock restore only for tracked products (mirrors checkout).
          final productRows = await txn.query(
            'products',
            where: 'id = ?',
            whereArgs: [productId],
            limit: 1,
          );
          if (productRows.isEmpty) {
            return failure('Product not found', code: 'not_found');
          }
          final product = productRows.first;
          if (product['track_stock'] == 1) {
            final stock = (product['stock_quantity'] as num).toDouble();
            final quantityAfter = stock + line.quantity;
            await txn.update(
              'products',
              {'stock_quantity': quantityAfter, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [productId],
            );
            await txn.insert(
              'stock_movements',
              {
                'uuid': newBusinessId(),
                'product_id': productId,
                'movement_type': 'sale_return',
                'quantity_change': line.quantity,
                'quantity_after': quantityAfter,
                'reference_type': 'return',
                'reference_id': returnUuid,
                'note': reason,
                'staff_uuid': staffUuid,
                'created_at': now,
              },
            );
          }
        }

        // Credit sales: reduce the customer's debt with a signed ledger row.
        if (sale['payment_method'] == 'credit' && sale['customer_id'] != null) {
          final customerId = sale['customer_id'] as int;
          final customerRows = await txn.query(
            'customers',
            where: 'id = ?',
            whereArgs: [customerId],
            limit: 1,
          );
          if (customerRows.isEmpty) {
            return failure('Customer not found', code: 'not_found');
          }
          final balance = customerRows.first['balance_minor'] as int;
          final newBalance = balance - refundTotal;
          await txn.insert(
            'customer_ledger',
            {
              'uuid': newBusinessId(),
              'customer_id': customerId,
              'entry_type': 'return_credit',
              'amount_minor': -refundTotal,
              'balance_after_minor': newBalance,
              'sale_uuid': sale['uuid'],
              'sale_id': saleId,
              'note': reason,
              'staff_uuid': staffUuid,
              'created_at': now,
            },
          );
          await txn.update(
            'customers',
            {'balance_minor': newBalance, 'updated_at': now},
            where: 'id = ?',
            whereArgs: [customerId],
          );
        }

        return success(
          SaleReturn(
            id: returnId,
            uuid: returnUuid,
            saleId: saleId,
            saleUuid: sale['uuid'] as String,
            customerId: sale['customer_id'] as int?,
            staffUuid: staffUuid,
            status: 'completed',
            refundTotalMinor: refundTotal,
            refundMethod: resolvedRefundMethod,
            reason: reason,
            createdAt: now,
            updatedAt: now,
          ),
        );
      });
    } on DatabaseException catch (e) {
      return failure('Unable to record return: $e', code: 'database');
    }
  }
}
