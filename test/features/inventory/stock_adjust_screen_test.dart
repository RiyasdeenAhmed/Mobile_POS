import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/inventory/data/stock_movement_repository.dart';
import 'package:qubexcore_pos/features/inventory/presentation/stock_adjust_screen.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/domain/product.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
import 'package:qubexcore_pos/features/staff/domain/staff_user.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// DB work is real async (same pattern as auth_gate_test / product form).
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
  late StockMovementRepository movements;
  late StaffSession session;

  Future<Product> seedProduct() async {
    return (await products.create(
      name: 'Espresso Beans',
      stockQuantity: 10,
      sellingPriceMinor: 1200,
    ))
        .dataOrNull!;
  }

  Future<void> openScreen(
    WidgetTester tester, {
    required String productUuid,
    required bool admin,
  }) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    session = StaffSession();
    session.adopt(StaffUser(
      uuid: 'staff-1',
      username: admin ? 'admin' : 'cashier1',
      displayName: admin ? 'Admin' : 'Cashier',
      role: admin ? 'admin' : 'cashier',
      createdAt: DateTime.now().toUtc().toIso8601String(),
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    ));

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: products),
            Provider<StockMovementRepository>.value(value: movements),
            ChangeNotifierProvider<StaffSession>.value(value: session),
          ],
          child: MaterialApp(
            home: StockAdjustScreen(productUuid: productUuid),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('admin records an adjustment with a required note',
      (tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    movements = StockMovementRepository(db);
    addTearDown(() => tester.runAsync(db.close));

    final product = await realAsync(tester, seedProduct);
    await openScreen(tester, productUuid: product.uuid, admin: true);

    expect(find.text('Adjust stock'), findsOneWidget);
    expect(find.text('Stock 10 · Reorder at 0'), findsOneWidget);

    // Missing note is rejected before any DB work.
    await tester.enterText(find.byType(TextFormField).at(0), '3');
    await tester.tap(find.widgetWithText(FilledButton, 'Record adjustment'));
    await tester.pumpAndSettle();
    expect(find.text('A note is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Weekly delivery');
    await tester.pump();
    expect(find.textContaining('Stock 10 → 13 (+3)'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Record adjustment'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    final stored =
        await realAsync(tester, () => products.findByUuid(product.uuid));
    expect(stored!.stockQuantity, 13);
    expect(find.text('Stock 13 · Reorder at 0'), findsOneWidget);
    expect(
      find.textContaining('+3 adjustment in'),
      findsOneWidget,
    );
    expect(find.textContaining('Weekly delivery'), findsOneWidget);
  });

  testWidgets('non-admin sees a lock instead of the adjustment form',
      (tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    movements = StockMovementRepository(db);
    addTearDown(() => tester.runAsync(db.close));

    final product = await realAsync(tester, seedProduct);
    await openScreen(tester, productUuid: product.uuid, admin: false);

    expect(find.text('Stock history'), findsOneWidget);
    expect(find.text('Only admins can adjust stock'), findsOneWidget);
    expect(find.text('Record adjustment'), findsNothing);
    expect(find.text('Movement history'), findsOneWidget);
  });
}
