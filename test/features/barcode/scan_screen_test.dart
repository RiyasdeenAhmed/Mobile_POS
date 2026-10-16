import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/barcode/data/fake_barcode_scanner.dart';
import 'package:qubexcore_pos/features/barcode/presentation/scan_screen.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_controller.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// sqflite FFI work is real async: every DB call runs inside tester.runAsync,
// then the result is rendered with the fake clock (pattern from
// pos_screens_test).
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
  late CartController cart;
  late FakeBarcodeScanner fake;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    cart = CartController();
    fake = FakeBarcodeScanner();
    addTearDown(() => tester.runAsync(db.close));
  }

  Future<void> seedProduct(WidgetTester tester, String barcode) async {
    await realAsync(tester, () async {
      await products.create(
        name: 'Cola',
        barcode: barcode,
        stockQuantity: 5,
        sellingPriceMinor: 300,
      );
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: products),
            ChangeNotifierProvider<CartController>.value(value: cart),
          ],
          child: MaterialApp(
            home: ScanScreen(scanner: fake),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
  }

  /// Emits codes and drains the real-async product lookup, then renders.
  Future<void> emitAndSettle(
    WidgetTester tester,
    List<String> codes,
  ) async {
    await realAsync(tester, () async {
      for (final code in codes) {
        fake.emit(code);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpAndSettle();
  }

  testWidgets('scanning a known barcode adds the product to the cart',
      (tester) async {
    await openDb(tester);
    await seedProduct(tester, '777123');
    await pumpScreen(tester);

    await emitAndSettle(tester, ['777123']);

    expect(find.text('Added Cola'), findsOneWidget);
    expect(cart.itemCount, 1);
    expect(cart.items.single.productName, 'Cola');
  });

  testWidgets('scanning an unknown barcode shows not found', (tester) async {
    await openDb(tester);
    await pumpScreen(tester);

    await emitAndSettle(tester, ['999999']);

    expect(find.text('Product not found'), findsOneWidget);
    expect(cart.isEmpty, isTrue);
  });

  testWidgets('re-scanning the same code within the debounce window is ignored',
      (tester) async {
    await openDb(tester);
    await seedProduct(tester, '777123');
    await pumpScreen(tester);

    await emitAndSettle(tester, ['777123', '777123']);

    expect(cart.itemCount, 1);
    expect(find.text('Added Cola'), findsOneWidget);
  });

  testWidgets('permission denied shows a card and keeps manual entry',
      (tester) async {
    await openDb(tester);
    fake.setPermissionDenied(true);
    await pumpScreen(tester);

    expect(find.text('Camera permission denied'), findsOneWidget);
    expect(find.text('Scanner ready'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add'), findsOneWidget);
  });

  testWidgets('manual barcode entry adds the product without the camera',
      (tester) async {
    await openDb(tester);
    await seedProduct(tester, '777123');
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '777123');
    await realAsync(tester, () async {
      await tester.tap(find.widgetWithText(TextButton, 'Add'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    expect(find.text('Added Cola'), findsOneWidget);
    expect(cart.itemCount, 1);
    await tester.scrollUntilVisible(find.byType(TextField), 160,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });
}
