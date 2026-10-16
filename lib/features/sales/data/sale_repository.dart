import '../../payments/domain/payment.dart';
import '../../../core/database/app_database.dart';
import '../domain/sale.dart';
import '../domain/sale_item.dart';

class SaleRepository {
  final AppDatabase database;

  SaleRepository(this.database);

  Future<List<Payment>> listPayments(int saleId) async {
    final rows = await database.db.query('payments',
        where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id ASC');
    return rows.map(Payment.fromMap).toList();
  }

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

  Future<List<Sale>> list({
    String? status,
    int? limit = 50,
    DateTime? from,
    DateTime? to,
    String? paymentMethod,
    int? customerId,
  }) async {
    final whereParts = <String>[];
    final whereArgs = <Object>[];
    if (status != null && status.isNotEmpty) {
      whereParts.add('status = ?');
      whereArgs.add(status);
    }
    if (from != null) {
      whereParts.add('sale_at >= ?');
      whereArgs.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      whereParts.add('sale_at < ?');
      whereArgs.add(to.toUtc().toIso8601String());
    }
    if (paymentMethod != null && paymentMethod.isNotEmpty) {
      whereParts.add('(payment_method = ? OR EXISTS (SELECT 1 FROM payments p WHERE p.sale_id = sales.id AND p.payment_method = ?))');
      whereArgs.addAll([paymentMethod, paymentMethod]);
    }
    if (customerId != null) {
      whereParts.add('customer_id = ?');
      whereArgs.add(customerId);
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

  /// Invoice-number lookup for the dashboard search.
  Future<List<Sale>> searchByInvoice(String query, {int? limit}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <Sale>[];
    final rows = await database.db.query(
      'sales',
      where: 'invoice_number LIKE ?',
      whereArgs: ['%$trimmed%'],
      orderBy: 'sale_at DESC',
      limit: limit,
    );
    return rows.map(Sale.fromMap).toList();
  }
}
