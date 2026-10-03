import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/staff_user.dart';

class StaffRepository {
  final AppDatabase database;

  StaffRepository(this.database);

  Future<AppResult<StaffUser>> create({
    required String username,
    required String displayName,
    String role = 'cashier',
    String? passwordHash,
  }) async {
    final trimmedUsername = username.trim();
    final trimmedName = displayName.trim();
    if (trimmedUsername.isEmpty) {
      return failure('Username is required', code: 'validation');
    }
    if (trimmedName.isEmpty) {
      return failure('Display name is required', code: 'validation');
    }
    if (role != 'admin' && role != 'manager' && role != 'cashier') {
      return failure('Invalid staff role', code: 'validation');
    }

    final now = utcNowIso();
    final user = StaffUser(
      uuid: newBusinessId(),
      username: trimmedUsername,
      displayName: trimmedName,
      role: role,
      passwordHash: passwordHash,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final id = await database.db.insert(
        'staff_users',
        user.toMap()..remove('id'),
      );
      return success(user.copyWith(id: id));
    } on DatabaseException catch (e) {
      final message = describeDatabaseError(e, 'Unable to create staff user');
      if (message.contains('username')) {
        return failure('A staff user with this username already exists',
            code: 'duplicate_username');
      }
      return failure(message, code: 'database');
    }
  }

  Future<StaffUser?> findById(int id) async {
    final rows = await database.db.query(
      'staff_users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StaffUser.fromMap(rows.first);
  }

  Future<StaffUser?> findByUuid(String uuid) async {
    final rows = await database.db.query(
      'staff_users',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StaffUser.fromMap(rows.first);
  }

  Future<StaffUser?> findByUsername(String username) async {
    final rows = await database.db.query(
      'staff_users',
      where: 'username = ?',
      whereArgs: [username.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return StaffUser.fromMap(rows.first);
  }

  Future<List<StaffUser>> list({bool includeArchived = false}) async {
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await database.db.query(
      'staff_users',
      where: where,
      orderBy: 'display_name COLLATE NOCASE ASC',
    );
    return rows.map(StaffUser.fromMap).toList();
  }
}
