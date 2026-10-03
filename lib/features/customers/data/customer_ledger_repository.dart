import '../../../core/database/app_database.dart';
import '../domain/customer_ledger_entry.dart';

class CustomerLedgerRepository {
  final AppDatabase database;

  CustomerLedgerRepository(this.database);

  Future<List<CustomerLedgerEntry>> listByCustomer(int customerId) async {
    final rows = await database.db.query(
      'customer_ledger',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(CustomerLedgerEntry.fromMap).toList();
  }

  Future<List<CustomerLedgerEntry>> listRecent({int limit = 50}) async {
    final rows = await database.db.query(
      'customer_ledger',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
    );
    return rows.map(CustomerLedgerEntry.fromMap).toList();
  }
}
