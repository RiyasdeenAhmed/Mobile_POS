import '../../../core/database/app_database.dart';

class ProfitSummary {
  const ProfitSummary(this.revenueMinor, this.costMinor, this.expensesMinor,
      this.zeroCostLines);
  final int revenueMinor, costMinor, expensesMinor, zeroCostLines;
  int get grossMinor => revenueMinor - costMinor;
  int get netMinor => grossMinor - expensesMinor;
}

class ProfitRepository {
  ProfitRepository(this.database);
  final AppDatabase database;
  Future<ProfitSummary> report(DateTime start, DateTime end) async {
    final bounds = [
      start.toUtc().toIso8601String(),
      end.toUtc().toIso8601String()
    ];
    // A read transaction gives all figures the same database snapshot.
    return database.db.transaction((txn) async {
      final sales = await txn.rawQuery('''SELECT i.* FROM sale_items i
        JOIN sales s ON s.id=i.sale_id WHERE s.status='completed'
        AND s.sale_at>=? AND s.sale_at<?''', bounds);
      final returns =
          await txn.rawQuery('''SELECT ri.quantity, ri.line_refund_minor,
        i.unit_cost_minor, (SELECT COALESCE(SUM(prior.quantity),0) FROM return_items prior
        JOIN returns pr ON pr.id=prior.return_id WHERE prior.sale_item_id=ri.sale_item_id
        AND pr.status='completed' AND (pr.created_at<r.created_at OR (pr.created_at=r.created_at AND prior.id<ri.id))) prior_quantity
        FROM return_items ri JOIN returns r ON r.id=ri.return_id
        JOIN sale_items i ON i.id=ri.sale_item_id WHERE r.status='completed'
        AND r.created_at>=? AND r.created_at<?''', bounds);
      var revenue = 0, cost = 0, zero = 0;
      for (final row in sales) {
        revenue += (row['line_total_minor'] as num).toInt();
        final unit = (row['unit_cost_minor'] as num).toInt();
        cost += (unit * (row['quantity'] as num)).round();
        if (unit == 0) zero++;
      }
      for (final row in returns) {
        revenue -= (row['line_refund_minor'] as num).toInt();
        final unit = row['unit_cost_minor'] as num,
            prior = row['prior_quantity'] as num;
        cost -= (unit * (prior + (row['quantity'] as num))).round() -
            (unit * prior).round();
      }
      final expenses = await txn.rawQuery(
          '''SELECT COALESCE(SUM(amount_minor),0) total
        FROM expenses WHERE voided_at IS NULL AND expense_at>=? AND expense_at<?''',
          bounds);
      return ProfitSummary(
          revenue, cost, (expenses.first['total'] as num).toInt(), zero);
    });
  }
}
