import 'package:qubexcore_pos/features/barcode/presentation/scan_screen.dart';
import 'package:qubexcore_pos/features/barcode/data/fake_barcode_scanner.dart';
import 'package:qubexcore_pos/features/checkout/presentation/checkout_screen.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_controller.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/receipts/presentation/receipt_screen.dart';
import 'package:qubexcore_pos/features/dashboard/presentation/more_screen.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/app/main_shell.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/pos/presentation/new_sale_screen.dart';
import 'package:qubexcore_pos/features/auth/presentation/login_screen.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
import 'package:qubexcore_pos/features/staff/domain/staff_user.dart';
import 'package:qubexcore_pos/features/profit/presentation/profit_screen.dart';
import 'package:qubexcore_pos/features/expenses/presentation/expenses_screen.dart';
import 'package:qubexcore_pos/features/products/presentation/product_import_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    for (final family in ['Inter', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family.ttf')))
          .load();
    }
  });
  for (final dark in [false, true]) {
    for (final width in [360.0, 768.0]) {
      testWidgets('retail screens render at $width dark=$dark', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        late AppDatabase db;
        late CartItem sample;
        late String saleUuid;
        await tester.runAsync(() async {
          db = await AppDatabase.open(path: inMemoryDatabasePath);
          await db.db.insert('staff_users', {
            'uuid': 'visual-admin',
            'username': 'admin',
            'display_name': 'Store Admin',
            'role': 'admin',
            'password_hash': '',
            'is_active': 1,
            'is_archived': 0,
            'created_at': '',
            'updated_at': ''
          });
          for (final name in [
            'Ceylon green tea',
            'Roasted coffee',
            'Whole grain bread',
            'Fresh milk'
          ]) {
            await ProductRepository(db).create(
                name: name, sellingPriceMinor: 125000, stockQuantity: 24);
          }
        });
        await tester.runAsync(() async {
          sample =
              CartItem.fromProduct((await ProductRepository(db).list()).first);
          final outcome =
              (await CheckoutService(db).completeSale(CheckoutRequest(
                      items: [sample],
                      paymentMethod: 'split',
                      staffUuid: 'visual-admin',
                      allocations: const [
                        PaymentAllocation(
                            method: 'cash',
                            amountMinor: 50000,
                            receivedMinor: 60000),
                        PaymentAllocation(method: 'qr', amountMinor: 75000)
                      ])))
                  .dataOrNull!;
          saleUuid = outcome.sale.uuid;
        });
        final scanner = FakeBarcodeScanner();
        final session = StaffSession()
          ..adopt(const StaffUser(
              uuid: 'visual-admin',
              username: 'admin',
              displayName: 'Store owner',
              role: 'admin',
              createdAt: '',
              updatedAt: ''));
        final screens = <String, Widget>{
          'login': const LoginScreen(),
          'sale': const NewSaleScreen(),
          'dashboard': const MainShell(),
          'profit': const ProfitScreen(),
          'expenses': const ExpensesScreen(),
          'import': const ProductImportScreen(),
          'more': const Scaffold(body: MoreScreen()),
          'checkout': const CheckoutScreen(),
          'scanner': ScanScreen(scanner: scanner),
          'receipt': ReceiptScreen(saleUuid: saleUuid),
        };
        for (final entry in screens.entries) {
          final key = GlobalKey();
          await tester.runAsync(() async {
            final cart = CartController()..addItem(sample);
            await tester.pumpWidget(MultiProvider(
                providers: [
                  ...buildAppProviders(db),
                  ChangeNotifierProvider<CartController>(create: (_) => cart),
                  ChangeNotifierProvider<StaffSession>.value(value: session)
                ],
                child: MaterialApp(
                    theme:
                        dark ? QubeXCoreTheme.dark() : QubeXCoreTheme.light(),
                    onGenerateRoute: AppRouter.onGenerateRoute,
                    home: RepaintBoundary(key: key, child: entry.value))));
            await Future<void>.delayed(const Duration(milliseconds: 300));
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: entry.key);
          if (width == 360) {
            await tester.runAsync(() async {
              final boundary = key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final dir =
                  await Directory('build/ui-preview').create(recursive: true);
              await File(
                      '${dir.path}/${entry.key}-${dark ? 'dark' : 'light'}.png')
                  .writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        }
        scanner.dispose();
        session.dispose();
        await tester.runAsync(db.close);
      });
    }
  }
}
