import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/presentation/checkout_screen.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_controller.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/receipts/data/mock_printer.dart';
import 'package:qubexcore_pos/features/receipts/data/receipt_print_service.dart';
import 'package:qubexcore_pos/features/sales/data/sale_repository.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
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
  late SettingsRepository settings;
  late CustomerRepository customers;
  late SaleRepository sales;
  late CartController cart;
  late MockPrinter printer;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    settings = SettingsRepository(db);
    customers = CustomerRepository(db);
    sales = SaleRepository(db);
    cart = CartController();
    printer = MockPrinter(fail: true);
    addTearDown(() => tester.runAsync(db.close));
  }

  testWidgets(
      'printer failure after checkout keeps the sale committed and '
      'reports it', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openDb(tester);
    await realAsync(tester, () async {
      await settings.setString('auto_print_receipt', '1');
      final product = (await products.create(
        name: 'Espresso',
        sellingPriceMinor: 600,
        stockQuantity: 10,
      ))
          .dataOrNull!;
      cart.addItem(CartItem.fromProduct(product));
    });

    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: products),
            Provider<CustomerRepository>.value(value: customers),
            Provider<SaleRepository>.value(value: sales),
            Provider<SettingsRepository>.value(value: settings),
            Provider<CheckoutService>.value(value: CheckoutService(db)),
            Provider<ReceiptPrintService>.value(
              value: ReceiptPrintService(
                printer: printer,
                settings: settings,
                customers: customers,
              ),
            ),
            ChangeNotifierProvider<CartController>.value(value: cart),
            ChangeNotifierProvider<StaffSession>.value(value: StaffSession()),
          ],
          child: const MaterialApp(
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: CheckoutScreen(),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();

    // Card payment submits without entering an amount.
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Credit card'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Credit card'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Complete sale'),
    );
    await realAsync(tester, () async {
      await tester.tap(find.widgetWithText(FilledButton, 'Complete sale'));
      // completeSale writes sale/items/payment/stock on the isolate-backed
      // FFI database; continuations need real windows interleaved with fake
      // pumps (M7 rhythm).
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    });
    // Render: the completion continuation runs (snackbar scheduled), the
    // receipt route is pushed, and its post-frame load starts.
    await tester.pump();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 800));
    });
    // Flush the load setState and render the receipt content.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(
      find.text('Sale completed — printing failed'),
      findsOneWidget,
    );
    // Receipt screen was pushed after the failure: navigation continues.
    expect(find.text('Receipt'), findsOneWidget);
    expect(printer.jobs, isEmpty);

    // The sale itself is committed: sale + item + payment rows exist.
    expect(await realAsync(tester, sales.count), 1);
    expect(cart.isEmpty, isTrue);
  });
}
