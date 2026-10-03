import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/categories/data/category_repository.dart';
import 'package:qubexcore_pos/features/categories/domain/category.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late CategoryRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates a category with a trimmed name', () async {
    final result = await repository.create(name: '  Coffee  ');
    expect(result.isSuccess, isTrue);
    final category = result.dataOrNull as Category;
    expect(category.name, 'Coffee');
    expect(category.parentId, isNull);
    expect(category.isArchived, isFalse);
  });

  test('rejects an empty category name', () async {
    final result = await repository.create(name: '   ');
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'validation');
  });

  test('rejects duplicate names case-insensitively', () async {
    expect((await repository.create(name: 'Tea')).isSuccess, isTrue);
    final duplicate = await repository.create(name: 'tea');
    expect(duplicate.isFailure, isTrue);
    expect(duplicate.failureOrNull?.code, 'duplicate_name');
  });

  test('supports parent categories', () async {
    final parent = (await repository.create(name: 'Drinks')).dataOrNull!;
    final child =
        (await repository.create(name: 'Cold drinks', parentId: parent.id))
            .dataOrNull!;
    expect(child.parentId, parent.id);

    final fetched = await repository.findByUuid(child.uuid);
    expect(fetched!.parentId, parent.id);
  });

  test('update renames and rejects clashing names', () async {
    final coffee = (await repository.create(name: 'Coffee')).dataOrNull!;
    expect((await repository.create(name: 'Tea')).isSuccess, isTrue);

    final clash = await repository.update(coffee.copyWith(name: 'tea'));
    expect(clash.isFailure, isTrue);
    expect(clash.failureOrNull?.code, 'duplicate_name');

    final renamed = await repository.update(coffee.copyWith(name: 'Espresso'));
    expect(renamed.isSuccess, isTrue);
    expect((await repository.findByUuid(coffee.uuid))!.name, 'Espresso');
  });

  test('update re-parents and rejects an invalid parent', () async {
    final drinks = (await repository.create(name: 'Drinks')).dataOrNull!;
    final food = (await repository.create(name: 'Food')).dataOrNull!;
    final juice = (await repository.create(name: 'Juice', parentId: drinks.id))
        .dataOrNull!;

    final moved = await repository.update(juice.copyWith(parentId: food.id));
    expect(moved.isSuccess, isTrue);
    expect((await repository.findByUuid(juice.uuid))!.parentId, food.id);

    final invalid = await repository.update(juice.copyWith(parentId: 999999));
    expect(invalid.isFailure, isTrue);
    expect(invalid.failureOrNull?.code, 'invalid_parent');
    expect((await repository.findByUuid(juice.uuid))!.parentId, food.id,
        reason: 'failed update must not change the row');
  });

  test('list excludes archived by default and sorts by sort order', () async {
    await repository.create(name: 'Zulu', sortOrder: 10);
    await repository.create(name: 'Alpha', sortOrder: 20);
    final toArchive = (await repository.create(name: 'Hidden')).dataOrNull!;
    await repository.archive(toArchive.uuid);

    final active = await repository.list();
    expect(active.map((c) => c.name).toList(), ['Zulu', 'Alpha']);
    expect((await repository.list(includeArchived: true)).length, 3);
  });

  test('productCount reports active products using the category', () async {
    final category = (await repository.create(name: 'Pastry')).dataOrNull!;
    final products = ProductRepository(db);
    await products.create(name: 'Croissant', categoryId: category.id);
    await products.create(name: 'Muffin', categoryId: category.id);
    await products.create(name: 'Plain');

    expect(await repository.productCount(category.id!), 2);
  });

  test('archive guard: categories with products are not archived', () async {
    final category = (await repository.create(name: 'Beans')).dataOrNull!;
    final products = ProductRepository(db);
    final created =
        (await products.create(name: 'Arabica', categoryId: category.id))
            .dataOrNull!;

    expect(await repository.productCount(category.id!), 1);
    await products.archive(created.uuid);
    expect(await repository.productCount(category.id!), 0);

    final result = await repository.archive(category.uuid);
    expect(result.isSuccess, isTrue);
    expect((await repository.findByUuid(category.uuid))!.isArchived, isTrue);
  });
}
