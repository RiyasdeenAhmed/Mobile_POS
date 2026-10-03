import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/categories/data/category_repository.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/domain/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ProductRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = ProductRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('creates product and finds by barcode', () async {
    final result = await repository.create(
      name: 'Espresso Beans',
      barcode: '1111111111111',
      sku: 'ESP-001',
      sellingPriceMinor: 1200,
      costPriceMinor: 700,
    );
    expect(result.isSuccess, isTrue);
    final product = result.dataOrNull as Product;
    expect(product.name, 'Espresso Beans');
    expect(product.uuid, isNotEmpty);

    final found = await repository.findByBarcode('1111111111111');
    expect(found, isNotNull);
    expect(found!.uuid, product.uuid);
  });

  test('archive hides product from default list', () async {
    final created = await repository.create(name: 'Archived Item');
    final product = created.dataOrNull as Product;

    final archived = await repository.archive(product.uuid);
    expect(archived.isSuccess, isTrue);

    final defaultList = await repository.list();
    expect(defaultList.any((p) => p.uuid == product.uuid), isFalse);

    final withArchived = await repository.list(includeArchived: true);
    expect(withArchived.any((p) => p.uuid == product.uuid), isTrue);
  });

  test('rejects empty product name', () async {
    final result = await repository.create(name: '   ');
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'validation');
  });

  test('rejects negative prices', () async {
    final result = await repository.create(
      name: 'Bad Price',
      sellingPriceMinor: -1,
    );
    expect(result.isFailure, isTrue);
  });

  test('create persists category, stock, reorder level and track flag',
      () async {
    final categories = CategoryRepository(db);
    final category = (await categories.create(name: 'Beans')).dataOrNull!;

    final result = await repository.create(
      name: 'House Blend',
      categoryId: category.id,
      stockQuantity: 12.5,
      reorderLevel: 5,
      trackStock: false,
      sellingPriceMinor: 1500,
    );
    expect(result.isSuccess, isTrue);

    final stored =
        await repository.findByUuid((result.dataOrNull as Product).uuid);
    expect(stored!.categoryId, category.id);
    expect(stored.stockQuantity, 12.5);
    expect(stored.reorderLevel, 5);
    expect(stored.trackStock, isFalse);
  });

  test('update changes details but never the stock quantity', () async {
    final created = (await repository.create(
      name: 'Old Name',
      stockQuantity: 7,
      sellingPriceMinor: 1000,
    ))
        .dataOrNull!;

    final edited = Product(
      id: created.id,
      uuid: created.uuid,
      name: 'New Name',
      sku: created.sku,
      barcode: created.barcode,
      categoryId: created.categoryId,
      costPriceMinor: created.costPriceMinor,
      sellingPriceMinor: 2500,
      currency: created.currency,
      stockQuantity: 999,
      reorderLevel: 3,
      trackStock: created.trackStock,
      isActive: created.isActive,
      isArchived: created.isArchived,
      createdAt: created.createdAt,
      updatedAt: created.updatedAt,
    );
    final result = await repository.update(edited);
    expect(result.isSuccess, isTrue);

    final stored = await repository.findByUuid(created.uuid);
    expect(stored!.name, 'New Name');
    expect(stored.sellingPriceMinor, 2500);
    expect(stored.reorderLevel, 3);
    expect(stored.stockQuantity, 7,
        reason: 'stock only changes via adjustStock');
  });

  test('search matches name, sku and barcode and skips archived', () async {
    await repository.create(name: 'Espresso Beans', sku: 'ESP-1');
    await repository.create(
        name: 'Filter Grind', sku: 'FLT-1', barcode: '999999');
    final archived =
        (await repository.create(name: 'Espresso Pods')).dataOrNull!;
    await repository.archive(archived.uuid);

    expect((await repository.search('espresso')).map((p) => p.name).toList(),
        ['Espresso Beans']);
    expect((await repository.search('FLT-1')).length, 1);
    expect((await repository.search('999999')).length, 1);
    expect((await repository.search('')).length, 2);
    expect((await repository.search('pods', includeArchived: true)).length, 1);
  });
}
