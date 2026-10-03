import '../../../core/database/app_database.dart';
import '../domain/sale.dart';
import '../domain/sale_item.dart';

class SaleRepository {
  final AppDatabase database;

  SaleRepository(this.database);

  Future<Sale?> findById(int id) async {
    final rows = await database.db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<List<SaleItem>> listItems(int saleId) async {
    final rows = await database.db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'id ASC',
    );
    return rows.map(SaleItem.fromMap).toList();
  }

  Future<Sale?> findByUuid(String uuid) async {
    final rows = await database.db.query(
      'sales',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Sale.fromMap(rows.first);
  }

  Future<List<Sale>> list({String? status, int limit = 50}) async {
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    }
    final rows = await database.db.query(
      'sales',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sale_at DESC',
      limit: limit,
    );
    return rows.map(Sale.fromMap).toList();
  }

  Future<int> count() async {
    final result =
        await database.db.rawQuery('SELECT COUNT(*) AS c FROM sales');
    final value = result.first['c'];
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }
}
