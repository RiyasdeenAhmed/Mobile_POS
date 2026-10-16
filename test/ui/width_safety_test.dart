import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/main_shell.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/auth/presentation/login_screen.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/settings/presentation/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Width-safety matrix for the Phase 1 screens (M12): every primary screen
/// must render without overflow at the narrow phone widths 360, 390 and 430.
/// RenderFlex overflows surface as test exceptions, so each step asserts
/// `tester.takeException()` is null.
Future<T> realAsync<T>(WidgetTester tester, Future<T> Function() body) async {
  late T result;
  await tester.runAsync(() async => result = await body());
  return result;
}

const List<double> _widths = [360, 390, 430];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  Widget app(Widget home) {
    return MultiProvider(
      providers: buildAppProviders(db),
      child: MaterialApp(
        theme: QubeXCoreTheme.light(),
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: home,
      ),
    );
  }

  /// Lets isolate-backed DB loads finish on a real event-loop turn, then
  /// renders the result with the fake clock.
  Future<void> settle(WidgetTester tester) async {
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Pushes a route with the proven interleave: spinner-driven frames starve
  /// pumpAndSettle while the isolate-backed DB read needs real windows.
  Future<void> pushSettle(WidgetTester tester, Finder tapTarget) async {
    await tester.runAsync(() async {
      await tester.tap(tapTarget);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  void expectNoOverflow(WidgetTester tester, String screen) {
    final exception = tester.takeException();
    expect(exception, isNull, reason: '$screen overflowed: $exception');
  }

  for (final width in _widths) {
    testWidgets('shell tabs, new sale, cart and checkout fit at $width px',
        (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await openDb(tester);

      // Seed purchasable and long-named records so list rows and money
      // lines are exercised at every width.
      await realAsync(tester, () async {
        final products = ProductRepository(db);
        final result = await products.create(
          name: 'Cappuccino',
          sellingPriceMinor: 600,
          stockQuantity: 10,
        );
        expect(result.dataOrNull, isNotNull);
        final long = await products.create(
          name: 'Premium Organic Wholegrain Loaf 500g Family Pack',
          sellingPriceMinor: 1290,
          stockQuantity: 4,
        );
        expect(long.dataOrNull, isNotNull);
        final customers = CustomerRepository(db);
        final customer = await customers.create(
          name: 'Kandy Roadside Groceries & Provisions',
          phone: '0771234567',
          creditLimitMinor: 50000,
        );
        expect(customer.dataOrNull, isNotNull);
      });

      await tester.pumpWidget(app(const MainShell()));
      await settle(tester);
      expectNoOverflow(tester, 'dashboard');
      expect(find.text('Today'), findsOneWidget);

      final navBar = find.byType(NavigationBar);
      for (final tab in ['Sales', 'Products', 'Customers', 'More']) {
        await tester.tap(
          find.descendant(of: navBar, matching: find.text(tab)),
        );
        await settle(tester);
        expectNoOverflow(tester, '$tab tab');
      }

      // New Sale via the shell app bar action.
      await pushSettle(tester, find.byTooltip('New Sale'));
      expect(find.text('New Sale'), findsWidgets);
      expectNoOverflow(tester, 'new sale');

      // Add the product to the cart, then dismiss the snackbar explicitly —
      // it floats over the bottom cart bar and would absorb the tap.
      await settle(tester);
      final productTile = find.text('Cappuccino');
      await tester.ensureVisible(productTile);
      await tester.pump();
      await tester.tap(productTile);
      await tester.pump();
      expectNoOverflow(tester, 'new sale after add');
      expect(find.textContaining('1 item'), findsOneWidget);
      tester
          .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
          .hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await pushSettle(tester, find.byTooltip('Cart'));
      expect(find.text('Proceed to Checkout'), findsOneWidget);
      expectNoOverflow(tester, 'cart');

      await pushSettle(tester, find.text('Proceed to Checkout'));
      expect(find.text('Cash'), findsOneWidget);
      expectNoOverflow(tester, 'checkout');

      // Settle any snackbars/timers started by cart actions.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('login and settings fit at $width px', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await openDb(tester);

      await tester.pumpWidget(app(const LoginScreen()));
      await settle(tester);
      expect(find.text('Enter PIN'), findsOneWidget);
      expectNoOverflow(tester, 'login');

      await tester.pumpWidget(app(const SettingsScreen()));
      await settle(tester);
      expect(find.text('Save settings'), findsOneWidget);
      expectNoOverflow(tester, 'settings (top)');

      // Scroll the long form so every section is laid out at this width.
      final list = find.byType(ListView);
      await tester.drag(list, const Offset(0, -900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectNoOverflow(tester, 'settings (middle)');
      await tester.drag(list, const Offset(0, -900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expectNoOverflow(tester, 'settings (bottom)');
      expect(find.text('Save settings'), findsOneWidget);
    });
  }
}
