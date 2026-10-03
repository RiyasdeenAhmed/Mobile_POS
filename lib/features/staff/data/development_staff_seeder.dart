import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/time_utils.dart';

const String developmentAdminUsername = 'admin';
const String developmentAdminPin = '1234';
const String developmentAdminDisplayName = 'Store Admin';

abstract final class DevelopmentStaffSeeder {
  static Future<void> seed(AppDatabase database,
      {int iterations = defaultIterations}) async {
    if (!kDebugMode) return;
    await seedAdmin(database, iterations: iterations);
  }

  static Future<void> seedAdmin(AppDatabase database,
      {int iterations = defaultIterations}) async {
    final db = database.db;
    final existing = await db.query(
      'staff_users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [developmentAdminUsername],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final now = utcNowIso();
    final uuid = newBusinessId();
    final hash =
        await PinHasher.hash(developmentAdminPin, iterations: iterations);

    try {
      await db.insert('staff_users', {
        'uuid': uuid,
        'username': developmentAdminUsername,
        'display_name': developmentAdminDisplayName,
        'role': 'admin',
        'password_hash': hash,
        'must_change_pin': 1,
        'is_active': 1,
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });
    } on DatabaseException {
      return;
    }
  }
}
