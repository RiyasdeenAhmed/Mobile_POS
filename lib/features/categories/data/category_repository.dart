import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/time_utils.dart';
import '../domain/category.dart';

class CategoryRepository {
  final AppDatabase database;

  CategoryRepository(this.database);

  Future<AppResult<Category>> create({
    required String name,
    int? parentId,
    int sortOrder = 0,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return failure('Category name is required', code: 'validation');
    }

    final now = utcNowIso();
    final category = Category(
      uuid: newBusinessId(),
      name: trimmedName,
      parentId: parentId,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final id = await database.db.insert(
        'categories',
        category.toMap()..remove('id'),
      );
      return success(category.copyWith(id: id));
    } on DatabaseException catch (e) {
      return failure(
        describeDatabaseError(e, 'Unable to create category'),
        code: 'database',
      );
    }
  }

  Future<AppResult<Category>> update(Category category) async {
    final trimmedName = category.name.trim();
    if (trimmedName.isEmpty) {
      return failure('Category name is required', code: 'validation');
    }
    final updated = category.copyWith(
      name: trimmedName,
      updatedAt: utcNowIso(),
    );
    await database.db.update(
      'categories',
      updated.toMap(),
      where: 'uuid = ?',
      whereArgs: [updated.uuid],
    );
    return success(updated);
  }

  Future<Category?> findById(int id) async {
    final rows = await database.db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<Category?> findByUuid(String uuid) async {
    final rows = await database.db.query(
      'categories',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<List<Category>> list({bool includeArchived = false}) async {
    final where = includeArchived ? null : 'is_archived = 0';
    final rows = await database.db.query(
      'categories',
      where: where,
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<AppResult<Category>> archive(String uuid) async {
    final category = await findByUuid(uuid);
    if (category == null) {
      return failure('Category not found', code: 'not_found');
    }
    final archived = category.copyWith(
      isArchived: true,
      updatedAt: utcNowIso(),
    );
    await database.db.update(
      'categories',
      {
        'is_archived': 1,
        'updated_at': archived.updatedAt,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return success(archived);
  }
}
