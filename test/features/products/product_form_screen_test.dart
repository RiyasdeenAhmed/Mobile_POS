import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/categories/data/category_repository.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/presentation/product_form_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// sqflite FFI work is real async: neither DB writes nor reads complete under
// FakeAsync, so every DB call and every tap that triggers one must run inside
// tester.runAsync (same pattern as auth_gate_test), then render with pump.
Future<T> realAsync<T>(WidgetTester tester, Future<T> Function() body) async {
  late T result;
  await tester.runAsync(() async => result = await body());
  return result;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ProductRepository products;
  late CategoryRepository categories;

  /// Tall surface so every ListView child (including the Save button at the
  /// bottom of the form) is built; layout responsiveness is covered by M12.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openDb(WidgetTester tester) async {
    useTallSurface(tester);
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    categories = CategoryRepository(db);
    addTearDown(() => tester.runAsync(db.close));
  }

  Future<void> openForm(
    WidgetTester tester, {
    String? productUuid,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: products),
            Provider<CategoryRepository>.value(value: categories),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProductFormScreen(
                          productUuid: productUuid,
                        ),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
    });
    // Build the pushed route so initState runs and _load() starts.
    await tester.pump();
    // The sqflite FFI read inside _load is real async: open a real window
    // for it to finish, otherwise the loading spinner never stops.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
  }

  /// Tap that triggers DB work: let the real async settle, then render.
  Future<void> tapReal(
    WidgetTester tester,
    Finder finder,
  ) async {
    await tester.runAsync(() async {
      await tester.tap(finder, warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('creates a product with category, stock and reorder level',
      (tester) async {
    await openDb(tester);
    final category = await realAsync(tester,
        () async => (await categories.create(name: 'Bakery')).dataOrNull!);

    await openForm(tester);
    expect(find.text('New product'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Croissant');
    await tester.enterText(find.byType(TextFormField).at(3), '1.50');
    await tester.enterText(find.byType(TextFormField).at(4), '3.00');
    await tester.enterText(find.byType(TextFormField).at(5), '4');
    await tester.enterText(find.byType(TextFormField).at(6), '12');
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bakery'));
    await tester.pumpAndSettle();

    await tapReal(tester, find.widgetWithText(ElevatedButton, 'Save product'));

    final saved = await realAsync(tester, products.list);
    expect(saved, hasLength(1));
    expect(saved.first.name, 'Croissant');
    expect(saved.first.sellingPriceMinor, 300);
    expect(saved.first.costPriceMinor, 150);
    expect(saved.first.stockQuantity, 12);
    expect(saved.first.reorderLevel, 4);
    expect(saved.first.categoryId, category.id);
  });

  testWidgets('rejects a missing name and a missing selling price',
      (tester) async {
    await openDb(tester);
    await openForm(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save product'));
    await tester.pumpAndSettle();

    expect(find.text('Name is required'), findsOneWidget);
    expect(find.text('Selling price is required'), findsOneWidget);
    final saved = await realAsync(tester, products.list);
    expect(saved, isEmpty);
  });

  testWidgets('edits an existing product without touching its stock',
      (tester) async {
    await openDb(tester);
    final created = await realAsync(
      tester,
      () async => (await products.create(
        name: 'Old Name',
        stockQuantity: 9,
        sellingPriceMinor: 500,
      ))
          .dataOrNull!,
    );

    await openForm(tester, productUuid: created.uuid);
    expect(find.text('Edit product'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Old Name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'New Name');
    await tester.enterText(find.byType(TextFormField).at(4), '7.50');
    await tester.pump();

    await tapReal(tester, find.widgetWithText(ElevatedButton, 'Save changes'));

    final stored =
        await realAsync(tester, () => products.findByUuid(created.uuid));
    expect(stored!.name, 'New Name');
    expect(stored.sellingPriceMinor, 750);
    expect(stored.stockQuantity, 9);
  });

  testWidgets('shows current stock read-only in edit mode', (tester) async {
    await openDb(tester);
    final created = await realAsync(
        tester,
        () async => (await products.create(name: 'Tracked', stockQuantity: 6))
            .dataOrNull!);

    await openForm(tester, productUuid: created.uuid);
    expect(find.text('Current stock: 6'), findsOneWidget);
    expect(find.text('Opening stock'), findsNothing);
    expect(
      find.text('Stock changes are recorded from the Inventory screen'),
      findsOneWidget,
    );
  });

  testWidgets('editing a deleted product shows an error', (tester) async {
    await openDb(tester);
    await openForm(tester, productUuid: 'missing-uuid');
    expect(find.text('Product not found'), findsOneWidget);
    expect(find.text('New product'), findsNothing);
  });
}
