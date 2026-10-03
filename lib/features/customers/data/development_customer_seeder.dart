import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/time_utils.dart';

/// Debug-only demo customers with credit limits. Idempotent — existing rows
/// (by name) are skipped.
abstract final class DevelopmentCustomerSeeder {
  static const List<Map<String, Object?>> _customers = [
    {
      'name': 'Nimal Perera',
      'phone': '0771234567',
      'creditLimitMinor': 50000,
    },
    {
      'name': 'Cafe Corner',
      'phone': '0775551234',
      'creditLimitMinor': 100000,
    },
  ];

  static Future<void> seed(AppDatabase database) async {
    if (!kDebugMode) return;
    final db = database.db;
    final now = utcNowIso();

    for (final customer in _customers) {
      final existing = await db.query(
        'customers',
        columns: ['id'],
        where: 'name = ?',
        whereArgs: [customer['name']],
        limit: 1,
      );
      if (existing.isNotEmpty) continue;
      try {
        await db.insert('customers', {
          'uuid': newBusinessId(),
          'name': customer['name'],
          'phone': customer['phone'],
          'credit_limit_minor': customer['creditLimitMinor'],
          'balance_minor': 0,
          'created_at': now,
          'updated_at': now,
        });
      } on DatabaseException {
        return;
      }
    }
  }
}
