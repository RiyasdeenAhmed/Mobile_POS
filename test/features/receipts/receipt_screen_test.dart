import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/payments/domain/payment.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/receipts/data/mock_printer.dart';
import 'package:qubexcore_pos/features/receipts/data/receipt_print_service.dart';
import 'package:qubexcore_pos/features/receipts/presentation/receipt_screen.dart';
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
  late MockPrinter printer;
  late ReceiptPrintService printService;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    settings = SettingsRepository(db);
    customers = CustomerRepository(db);
    sales = SaleRepository(db);
    printer = MockPrinter();
    printService = ReceiptPrintService(
      printer: printer,
      settings: settings,
      customers: customers,
    );
    addTearDown(() => tester.runAsync(db.close));
  }

  Future<String> completeSale(WidgetTester tester) async {
    return realAsync(tester, () async {
      final product = (await products.create(
        name: 'Espresso',
        sellingPriceMinor: 600,
        stockQuantity: 10,
      ))
          .dataOrNull!;
      final result = await CheckoutService(db).completeSale(
        CheckoutRequest(
          items: [CartItem.fromProduct(product)],
          paymentMethod: PaymentMethods.cash,
          cashReceivedMinor: 1000,
        ),
      );
      return result.dataOrNull!.sale.uuid;
    });
  }

  Future<void> pumpScreen(WidgetTester tester, String saleUuid) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<SaleRepository>.value(value: sales),
            Provider<ReceiptPrintService>.value(value: printService),
            Provider<CustomerRepository>.value(value: customers),
            ChangeNotifierProvider<StaffSession>.value(value: StaffSession()),
          ],
          child: MaterialApp(
            home: ReceiptScreen(saleUuid: saleUuid),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
  }

  testWidgets('receipt shows settings-driven shop name and footer',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openDb(tester);
    await realAsync(tester, () async {
      await settings.setString('store_name', 'Corner Kade');
      await settings.setString('store_address', '12 Main Street');
      await settings.setString('receipt_footer', 'Come again soon');
    });
    final saleUuid = await completeSale(tester);
    await pumpScreen(tester, saleUuid);

    expect(find.text('Corner Kade'), findsOneWidget);
    expect(find.text('12 Main Street'), findsOneWidget);
    expect(find.text('Come again soon'), findsOneWidget);
    expect(find.textContaining('INV-'), findsOneWidget);
    expect(find.text('Method: CASH'), findsOneWidget);
    expect(find.textContaining('1 × Espresso'), findsOneWidget);
  });

  testWidgets('manual reprint sends the receipt to the printer',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openDb(tester);
    final saleUuid = await completeSale(tester);
    await pumpScreen(tester, saleUuid);

    await realAsync(tester, () async {
      await tester.tap(find.byTooltip('Print'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('Receipt sent to printer'), findsOneWidget);
    expect(printer.jobs, hasLength(1));
    expect(await realAsync(tester, sales.count), 1);
  });

  testWidgets('printer failure keeps the sale and shows an error',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openDb(tester);
    printer.fail = true;
    final saleUuid = await completeSale(tester);
    await pumpScreen(tester, saleUuid);

    await realAsync(tester, () async {
      await tester.tap(find.byTooltip('Print'));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();

    expect(find.text('Printer is unavailable'), findsOneWidget);
    expect(printer.jobs, isEmpty);
    expect(await realAsync(tester, sales.count), 1);
  });
}
