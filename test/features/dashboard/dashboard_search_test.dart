import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/dashboard/presentation/dashboard_screen.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ProductRepository products;
  late CustomerRepository customers;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    products = ProductRepository(database);
    customers = CustomerRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> seedData(WidgetTester tester) async {
    await tester.runAsync(() async {
      await products.create(
        name: 'Espresso Machine',
        sellingPriceMinor: 45000,
        stockQuantity: 3,
      );
      await customers.create(name: 'Nimal Perera', phone: '0771234567');
      final now = DateTime.now().toUtc().toIso8601String();
      await database.db.insert('sales', <String, Object?>{
        'uuid': 'sale-inv-0042',
        'invoice_number': 'INV-0042',
        'sale_at': now,
        'subtotal_minor': 1000,
        'total_minor': 1000,
        'amount_paid_minor': 1000,
        'status': 'completed',
        'payment_method': 'cash',
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final List<SingleChildWidget> providers = buildAppProviders(database);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            theme: QubeXCoreTheme.light(),
            onGenerateRoute: AppRouter.onGenerateRoute,
            // The shell supplies the Material ancestor in the real app.
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );
    });
    await tester.pump();
    await tester.pump();
  }

  Future<void> waitFor(
    WidgetTester tester,
    bool Function() condition, {
    int attempts = 40,
  }) async {
    for (var i = 0; i < attempts && !condition(); i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }
  }

  testWidgets(
    'search shows grouped results after debounce and opens a product result',
    (tester) async {
      await seedData(tester);
      await pumpApp(tester);
      expect(find.text('Quick actions'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'espr');
      await tester.pump();
      // Typing replaces the quick actions with the searching state.
      expect(find.text('Quick actions'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);

      // The 300ms debounce has not fired yet.
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Espresso Machine'), findsNothing);

      await tester.pump(const Duration(milliseconds: 200));
      await waitFor(
        tester,
        () => find.text('Espresso Machine').evaluate().isNotEmpty,
      );

      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Espresso Machine'), findsOneWidget);
      expect(find.text('Customers'), findsNothing);
      expect(find.text('Invoices'), findsNothing);
      expect(find.text('Quick actions'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.runAsync(() async {
        await tester.tap(find.text('Espresso Machine'));
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await waitFor(
        tester,
        () => find.text('Edit product').evaluate().isNotEmpty,
      );
      expect(find.text('Edit product'), findsOneWidget);
    },
  );

  testWidgets(
    'search groups customers by name/phone and invoices by number',
    (tester) async {
      await seedData(tester);
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'nimal');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(
        tester,
        () => find.text('Nimal Perera').evaluate().isNotEmpty,
      );
      expect(find.text('Customers'), findsOneWidget);
      expect(find.text('0771234567'), findsOneWidget);
      expect(find.text('Products'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '0042');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(
        tester,
        () => find.text('INV-0042').evaluate().isNotEmpty,
      );
      expect(find.text('Invoices'), findsOneWidget);
      expect(find.text('Customers'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'no-match search shows an empty state and clearing restores quick actions',
    (tester) async {
      await seedData(tester);
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(
        tester,
        () => find.text('No matches').evaluate().isNotEmpty,
      );
      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Quick actions'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('No matches'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing the query during the debounce never shows stale results',
    (tester) async {
      await seedData(tester);
      await pumpApp(tester);

      await tester.enterText(find.byType(TextField), 'espr');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await waitFor(
        tester,
        () => find.text('No matches').evaluate().isNotEmpty,
      );
      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('Espresso Machine'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
