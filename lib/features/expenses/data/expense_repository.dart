import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../staff/application/staff_session.dart';

class ExpenseRepository {
  ExpenseRepository(this.database, this.session);
  final AppDatabase database;
  final StaffSession session;
  static const categories = [
    'Rent',
    'Salaries',
    'Utilities',
    'Transport',
    'Supplies',
    'Other'
  ];
  void _authorize() {
    if (!session.isAdmin) throw StateError('Administrator access required');
  }

  Future<List<Map<String, Object?>>> list() async {
    _authorize();
    return database.db.query('expenses', orderBy: 'expense_at DESC, id DESC');
  }

  Future<void> add(
      {required int amount,
      required String category,
      required DateTime date,
      String note = '',
      int? replaces}) async {
    _authorize();
    if (amount <= 0 || !categories.contains(category)) {
      throw ArgumentError('Enter a positive amount and category');
    }
    await database.db.transaction((txn) async {
      if (replaces != null) {
        await _void(txn, replaces, 'Replaced by corrected entry');
      }
      await txn.insert('expenses', {
        'uuid': newBusinessId(),
        'amount_minor': amount,
        'category': category,
        'expense_at':
            DateTime(date.year, date.month, date.day).toUtc().toIso8601String(),
        'note': note.trim(),
        'staff_uuid': session.staffUuid,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'replaces_id': replaces
      });
    });
    database.financialChanged();
  }

  Future<void> voidEntry(int id, String reason) async {
    _authorize();
    if (reason.trim().isEmpty) throw ArgumentError('Reason required');
    await database.db.transaction((txn) => _void(txn, id, reason.trim()));
    database.financialChanged();
  }

  Future<void> _void(Transaction txn, int id, String reason) async {
    final count = await txn.update(
        'expenses',
        {
          'voided_at': DateTime.now().toUtc().toIso8601String(),
          'voided_by': session.staffUuid,
          'void_reason': reason
        },
        where: 'id=? AND voided_at IS NULL',
        whereArgs: [id]);
    if (count != 1) throw StateError('Expense has already been voided');
  }
}
