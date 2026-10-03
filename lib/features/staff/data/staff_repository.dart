import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/security/pin_hasher.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/staff_user.dart';

const int minPinLength = 4;
const int maxPinLength = 8;

class StaffRepository {
  final AppDatabase database;

  /// PBKDF2 work factor for hashes this repository writes. Production keeps the
  /// top-level `defaultIterations` constant; tests inject a low value.
  /// Verification always honours the count stored inside the encoded hash.
  final int pinIterations;

  StaffRepository(this.database, {this.pinIterations = defaultIterations});

  static bool isValidPinFormat(String pin) {
    return pin.length >= minPinLength &&
        pin.length <= maxPinLength &&
        RegExp(r'^\d+$').hasMatch(pin);
  }

  Future<AppResult<StaffUser>> verifyPin({
    required String username,
    required String pin,
  }) async {
    final trimmedUsername = username.trim();
    if (trimmedUsername.isEmpty) {
      return failure('Username is required', code: 'validation');
    }
    if (pin.isEmpty) {
      return failure('PIN is required', code: 'validation');
    }

    final user = await findByUsername(trimmedUsername);
    if (user == null) {
      return failure('Incorrect username or PIN', code: 'invalid_credentials');
    }
    if (!user.isActive || user.isArchived) {
      return failure('This staff account is not active',
          code: 'inactive_account');
    }

    final storedHash = user.passwordHash;
    if (storedHash == null || storedHash.isEmpty) {
      return failure('This staff account has no PIN set',
          code: 'invalid_credentials');
    }

    final matches = await PinHasher.verify(pin: pin, encodedHash: storedHash);
    if (!matches) {
      return failure('Incorrect username or PIN', code: 'invalid_credentials');
    }

    return success(user);
  }

  Future<AppResult<StaffUser>> changePin({
    required String uuid,
    required String currentPin,
    required String newPin,
  }) async {
    if (!isValidPinFormat(newPin)) {
      return failure(
        'PIN must be $minPinLength to $maxPinLength digits',
        code: 'validation',
      );
    }

    final user = await findByUuid(uuid);
    if (user == null) {
      return failure('Staff user not found', code: 'not_found');
    }

    final storedHash = user.passwordHash;
    if (storedHash == null || storedHash.isEmpty) {
      return failure('This staff account has no PIN set',
          code: 'invalid_credentials');
    }
    final matches =
        await PinHasher.verify(pin: currentPin, encodedHash: storedHash);
    if (!matches) {
      return failure('Current PIN is incorrect', code: 'invalid_credentials');
    }

    return setPin(uuid: uuid, newPin: newPin);
  }

  Future<AppResult<StaffUser>> setPin({
    required String uuid,
    required String newPin,
  }) async {
    if (!isValidPinFormat(newPin)) {
      return failure(
        'PIN must be $minPinLength to $maxPinLength digits',
        code: 'validation',
      );
    }

    final user = await findByUuid(uuid);
    if (user == null) {
      return failure('Staff user not found', code: 'not_found');
    }

    final hash = await PinHasher.hash(newPin, iterations: pinIterations);
    final now = utcNowIso();
    await database.db.update(
      'staff_users',
      {
        'password_hash': hash,
        'must_change_pin': 0,
        'updated_at': now,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    return success(user.copyWith(
      passwordHash: hash,
      mustChangePin: false,
      updatedAt: now,
    ));
  }

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

  Future<AppResult<StaffUser>> update({
    required String uuid,
    required String displayName,
    required String role,
  }) async {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      return failure('Display name is required', code: 'validation');
    }
    if (role != 'admin' && role != 'manager' && role != 'cashier') {
      return failure('Invalid staff role', code: 'validation');
    }

    final user = await findByUuid(uuid);
    if (user == null) {
      return failure('Staff user not found', code: 'not_found');
    }

    final now = utcNowIso();
    await database.db.update(
      'staff_users',
      {'display_name': trimmedName, 'role': role, 'updated_at': now},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    return success(user.copyWith(
      displayName: trimmedName,
      role: role,
      updatedAt: now,
    ));
  }

  Future<AppResult<StaffUser>> setArchived({
    required String uuid,
    required bool archived,
  }) async {
    final user = await findByUuid(uuid);
    if (user == null) {
      return failure('Staff user not found', code: 'not_found');
    }

    final now = utcNowIso();
    await database.db.update(
      'staff_users',
      {
        'is_archived': archived ? 1 : 0,
        'is_active': archived ? 0 : 1,
        'updated_at': now,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );

    return success(user.copyWith(
      isArchived: archived,
      isActive: !archived,
      updatedAt: now,
    ));
  }

  Future<bool> isLastActiveAdmin(String uuid) async {
    final user = await findByUuid(uuid);
    if (user == null || user.role != 'admin') return false;
    final rows = await database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM staff_users '
      'WHERE role = ? AND is_active = 1 AND is_archived = 0',
      ['admin'],
    );
    final count = (rows.first['c'] as int?) ?? 0;
    return count <= 1;
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
