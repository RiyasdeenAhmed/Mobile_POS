import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/customer.dart';

class RepaymentService {
  final AppDatabase database;

  RepaymentService(this.database);

  /// Records a repayment atomically: one negative-signed ledger entry plus
  /// the customer balance update. Never touches the original credit sale.
  Future<AppResult<int>> recordRepayment({
    required String customerUuid,
    required int amountMinor,
    String? note,
    String? staffUuid,
  }) async {
    if (amountMinor <= 0) {
      return failure(
        'Repayment amount must be greater than zero',
        code: 'validation',
      );
    }
    final now = utcNowIso();
    try {
      return await database.db.transaction<AppResult<int>>((txn) async {
        final rows = await txn.query(
          'customers',
          where: 'uuid = ?',
          whereArgs: [customerUuid],
          limit: 1,
        );
        if (rows.isEmpty) {
          return failure('Customer not found', code: 'not_found');
        }
        final customer = Customer.fromMap(rows.first);
        final customerId = customer.id;
        if (customerId == null) {
          return failure('Customer not found', code: 'not_found');
        }

        final newBalance = customer.balanceMinor - amountMinor;
        if (newBalance < 0) {
          return failure(
            'Repayment exceeds the outstanding balance',
            code: 'overpayment',
          );
        }

        await txn.insert(
          'customer_ledger',
          {
            'uuid': newBusinessId(),
            'customer_id': customerId,
            'entry_type': 'repayment',
            'amount_minor': -amountMinor,
            'balance_after_minor': newBalance,
            'sale_uuid': null,
            'sale_id': null,
            'note': note,
            'staff_uuid': staffUuid,
            'created_at': now,
          },
        );
        await txn.update(
          'customers',
          {
            'balance_minor': newBalance,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [customerId],
        );
        return success(newBalance);
      });
    } on DatabaseException catch (e) {
      return failure(
        'Unable to record repayment: $e',
        code: 'database',
      );
    }
  }
}
