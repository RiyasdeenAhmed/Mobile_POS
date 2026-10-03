import '../../../core/database/app_database.dart';

class DashboardMetrics {
  final int todaySalesTotalMinor;
  final int todayTransactionCount;
  final int outstandingCreditMinor;
  final int lowStockCount;

  const DashboardMetrics({
    required this.todaySalesTotalMinor,
    required this.todayTransactionCount,
    required this.outstandingCreditMinor,
    required this.lowStockCount,
  });
}

/// Dashboard aggregates for the current UTC day, matching `utcNowIso()`
/// storage (UTC ISO-8601 strings compare lexicographically).
class DashboardRepository {
  final AppDatabase database;

  DashboardRepository(this.database);

  ({String start, String end}) _todayWindow() {
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return (start: start.toIso8601String(), end: end.toIso8601String());
  }

  Future<DashboardMetrics> metrics() async {
    final window = _todayWindow();
    final salesRow = (await database.db.rawQuery(
      '''
      SELECT COALESCE(SUM(total_minor), 0) AS total,
             COUNT(*) AS count
      FROM sales
      WHERE status = 'completed'
        AND sale_at >= ? AND sale_at < ?
      ''',
      [window.start, window.end],
    ))
        .first;
    final creditRow = (await database.db.rawQuery(
      'SELECT COALESCE(SUM(balance_minor), 0) AS total '
      'FROM customers WHERE balance_minor > 0 AND is_archived = 0',
    ))
        .first;
    final lowStockRow = (await database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM products '
      'WHERE track_stock = 1 AND is_archived = 0 '
      'AND stock_quantity <= reorder_level',
    ))
        .first;

    return DashboardMetrics(
      todaySalesTotalMinor: _asInt(salesRow['total']),
      todayTransactionCount: _asInt(salesRow['count']),
      outstandingCreditMinor: _asInt(creditRow['total']),
      lowStockCount: _asInt(lowStockRow['c']),
    );
  }

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}
