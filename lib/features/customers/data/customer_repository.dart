import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/customer.dart';

class CustomerRepository {
  final AppDatabase database;

  CustomerRepository(this.database);

  Future<AppResult<Customer>> create({
    required String name,
    String? phone,
    String? email,
    String? address,
    int creditLimitMinor = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return failure('Customer name is required', code: 'validation');
    }
    if (creditLimitMinor < 0) {
      return failure('Credit limit cannot be negative', code: 'validation');
    }

    final now = utcNowIso();
    final customer = Customer(
      uuid: newBusinessId(),
      name: trimmedName,
      phone: _normalizeOptional(phone),
      email: _normalizeOptional(email),
      address: _normalizeOptional(address),
      creditLimitMinor: creditLimitMinor,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final id = await database.db.insert(
        'customers',
        customer.toMap()..remove('id'),
      );
      return success(customer.copyWith(id: id));
    } on DatabaseException catch (e) {
      return failure(
        describeDatabaseError(e, 'Unable to create customer'),
        code: 'database',
      );
    }
  }

  Future<AppResult<Customer>> update(Customer customer) async {
    final trimmedName = customer.name.trim();
    if (trimmedName.isEmpty) {
      return failure('Customer name is required', code: 'validation');
    }
    if (customer.creditLimitMinor < 0) {
      return failure('Credit limit cannot be negative', code: 'validation');
    }
    final updated = customer.copyWith(
      name: trimmedName,
      phone: _normalizeOptional(customer.phone),
      email: _normalizeOptional(customer.email),
      address: _normalizeOptional(customer.address),
      updatedAt: utcNowIso(),
    );
    await database.db.update(
      'customers',
      updated.toMap(),
      where: 'uuid = ?',
      whereArgs: [updated.uuid],
    );
    return success(updated);
  }

  Future<Customer?> findById(int id) async {
    final rows = await database.db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<Customer?> findByUuid(String uuid) async {
    final rows = await database.db.query(
      'customers',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<List<Customer>> list({bool includeArchived = false}) async {
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await database.db.query(
      'customers',
      where: where,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<AppResult<Customer>> archive(String uuid) async {
    final customer = await findByUuid(uuid);
    if (customer == null) {
      return failure('Customer not found', code: 'not_found');
    }
    final archived = customer.copyWith(
      isArchived: true,
      updatedAt: utcNowIso(),
    );
    await database.db.update(
      'customers',
      {
        'is_archived': 1,
        'updated_at': archived.updatedAt,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return success(archived);
  }

  String? _normalizeOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
