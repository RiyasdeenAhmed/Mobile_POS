import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
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
}
