import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/inventory/data/stock_movement_repository.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/domain/product.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ProductRepository products;
  late StockMovementRepository movements;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    products = ProductRepository(db);
    movements = StockMovementRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Product> seedProduct({
    String name = 'Beans',
    double stock = 10,
    double reorder = 0,
    bool track = true,
  }) async {
    return (await products.create(
      name: name,
      stockQuantity: stock,
      reorderLevel: reorder,
      trackStock: track,
      sellingPriceMinor: 1000,
    ))
        .dataOrNull!;
  }

  group('adjustStock signs', () {
    test('adjustment_in increases stock and records the movement', () async {
      final product = await seedProduct(stock: 10);
      final result = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: 5,
        movementType: 'adjustment_in',
        note: 'Delivery',
      );
      expect(result.isSuccess, isTrue);

      final stored = await products.findByUuid(product.uuid);
      expect(stored!.stockQuantity, 15);

      final rows = await movements.listByProduct(product.id!);
      expect(rows, hasLength(2));
      expect(rows.first.movementType, 'adjustment_in');
      expect(rows.first.quantityChange, 5);
      expect(rows.first.quantityAfter, 15);
      expect(rows.first.note, 'Delivery');
    });

    test('adjustment_out decreases stock (sign defect fix)', () async {
      final product = await seedProduct(stock: 10);
      final result = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -3,
        movementType: 'adjustment_out',
        note: 'Shelf count correction',
      );
      expect(result.isSuccess, isTrue,
          reason: 'out-movements must be accepted with a negative quantity');

      final stored = await products.findByUuid(product.uuid);
      expect(stored!.stockQuantity, 7);

      final rows = await movements.listByProduct(product.id!);
      expect(rows.first.quantityChange, -3);
      expect(rows.first.quantityAfter, 7);
    });

    test('damage removes stock; a positive damage quantity is rejected',
        () async {
      final product = await seedProduct(stock: 8);

      final wrongSign = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: 2,
        movementType: 'damage',
        note: 'Broken pack',
      );
      expect(wrongSign.isFailure, isTrue);

      final correct = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -2,
        movementType: 'damage',
        note: 'Broken pack',
      );
      expect(correct.isSuccess, isTrue);
      expect((await products.findByUuid(product.uuid))!.stockQuantity, 6);
    });

    test('purchase must be positive', () async {
      final product = await seedProduct(stock: 4);
      final wrongSign = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -1,
        movementType: 'purchase',
        note: 'Return to supplier',
      );
      expect(wrongSign.isFailure, isTrue);

      final correct = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: 6,
        movementType: 'purchase',
        note: 'Weekly delivery',
      );
      expect(correct.isSuccess, isTrue);
      expect((await products.findByUuid(product.uuid))!.stockQuantity, 10);
    });

    test('zero change and unsupported types are rejected', () async {
      final product = await seedProduct();
      final zero = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: 0,
        movementType: 'adjustment_in',
        note: 'x',
      );
      expect(zero.isFailure, isTrue);
      expect(zero.failureOrNull?.code, 'validation');

      final unsupported = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -1,
        movementType: 'sale',
        note: 'x',
      );
      expect(unsupported.isFailure, isTrue);
    });
  });

  group('adjustStock guards', () {
    test('manual adjustments require a note', () async {
      final product = await seedProduct();
      final result = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -1,
        movementType: 'adjustment_out',
        note: '  ',
      );
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('note'));
      expect((await products.findByUuid(product.uuid))!.stockQuantity, 10);
    });

    test('stock cannot fall below zero', () async {
      final product = await seedProduct(stock: 2);
      final result = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -5,
        movementType: 'damage',
        note: 'Fire',
      );
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('negative'));
      expect((await products.findByUuid(product.uuid))!.stockQuantity, 2);

      final rows = await movements.listByProduct(product.id!);
      expect(rows.single.movementType, 'opening_stock',
          reason: 'failed adjustment must not write a movement');
    });

    test('allow_negative_stock setting permits negative stock', () async {
      await db.db.insert(
          'app_settings',
          {
            'key': 'allow_negative_stock',
            'value': '1',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      final product = await seedProduct(stock: 2);
      final result = await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: -5,
        movementType: 'damage',
        note: 'Fire',
      );
      expect(result.isSuccess, isTrue);
      expect((await products.findByUuid(product.uuid))!.stockQuantity, -3);

      final rows = await movements.listByProduct(product.id!);
      expect(rows.first.quantityAfter, -3);
    });

    test('records the staff uuid on the movement', () async {
      final product = await seedProduct();
      await movements.adjustStock(
        productUuid: product.uuid,
        quantityChange: 1,
        movementType: 'purchase',
        note: 'Delivery',
        staffUuid: 'staff-uuid-1',
      );
      final rows = await movements.listByProduct(product.id!);
      expect(rows.first.staffUuid, 'staff-uuid-1');
    });
  });

  group('queries', () {
    test('lowStockProducts flags tracked stock at or below reorder level',
        () async {
      await seedProduct(name: 'Low', stock: 2, reorder: 5);
      await seedProduct(name: 'Out', stock: 0, reorder: 0);
      await seedProduct(name: 'Fine', stock: 20, reorder: 5);
      await seedProduct(name: 'Untracked', stock: 0, reorder: 0, track: false);
      final archived = await seedProduct(name: 'Old', stock: 0, reorder: 0);
      await products.archive(archived.uuid);

      final low = await movements.lowStockProducts();
      expect(low.map((p) => p.name).toList(), ['Out', 'Low']);
      expect(await movements.lowStockCount(), 2);
    });

    test('listRecent joins the product name newest first', () async {
      final a = await seedProduct(name: 'Alpha', stock: 1);
      final b = await seedProduct(name: 'Beta', stock: 1);
      await movements.adjustStock(
        productUuid: a.uuid,
        quantityChange: 1,
        movementType: 'purchase',
        note: 'A',
      );
      await movements.adjustStock(
        productUuid: b.uuid,
        quantityChange: 2,
        movementType: 'purchase',
        note: 'B',
      );

      final recent = await movements.listRecent(limit: 4);
      expect(recent, hasLength(4));
      expect(recent.first.productName, 'Beta');
      expect(recent.first.note, 'B');
      expect(recent.last.productName, 'Alpha',
          reason: 'oldest movement is the Alpha opening stock');
    });
  });
}
