import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/main_shell.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/sales/data/sale_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> insertSale({
    required String uuid,
    required String invoiceNumber,
    required String saleAt,
  }) async {
    await database.db.insert('sales', <String, Object?>{
      'uuid': uuid,
      'invoice_number': invoiceNumber,
      'sale_at': saleAt,
      'subtotal_minor': 1000,
      'total_minor': 1000,
      'amount_paid_minor': 1000,
      'status': 'completed',
      'payment_method': 'cash',
      'created_at': saleAt,
      'updated_at': saleAt,
    });
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    String? initialRoute,
    SaleRepository? saleRepositoryOverride,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final List<SingleChildWidget> providers = buildAppProviders(database);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: Provider<SaleRepository>.value(
            value: saleRepositoryOverride ?? SaleRepository(database),
            child: MaterialApp(
              theme: QubeXCoreTheme.light(),
              onGenerateRoute: AppRouter.onGenerateRoute,
              initialRoute: initialRoute,
              home: initialRoute == null ? const MainShell() : null,
            ),
          ),
        ),
      );
    });
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, {int rounds = 3}) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    });
    for (var i = 0; i < rounds; i++) {
      await tester.pump();
    }
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
    'dashboard Sales quick action opens the sales route without errors',
    (tester) async {
      await pumpApp(tester);

      await tester.runAsync(() async {
        await tester.tap(find.text('History'), warnIfMissed: false);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('No sales yet'), findsOneWidget);
    },
  );

  testWidgets(
    '/sales route renders filters, empty state, and pull-to-refresh',
    (tester) async {
      await pumpApp(tester, initialRoute: AppRoutes.sales);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(8));
      expect(find.text('No sales yet'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.padding,
        const EdgeInsets.fromLTRB(16, 16, 16, 96),
      );
    },
  );

  testWidgets(
    'Today and Yesterday filters follow the local calendar day',
    (tester) async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      await tester.runAsync(() async {
        await insertSale(
          uuid: 'sale-today',
          invoiceNumber: 'INV-TODAY',
          saleAt: todayStart
              .add(const Duration(hours: 1))
              .toUtc()
              .toIso8601String(),
        );
        await insertSale(
          uuid: 'sale-yesterday',
          invoiceNumber: 'INV-YESTERDAY',
          saleAt: DateTime(now.year, now.month, now.day - 1, 23, 30)
              .toUtc()
              .toIso8601String(),
        );
      });

      await pumpApp(tester, initialRoute: AppRoutes.sales);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('INV-TODAY'), findsOneWidget);
      expect(find.text('INV-YESTERDAY'), findsNothing);

      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.runAsync(() async {
        await tester.tap(find.text('Yesterday').last, warnIfMissed: false);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();
      await tester.pump();
      await waitFor(
          tester, () => find.text('INV-YESTERDAY').evaluate().isNotEmpty);

      expect(tester.takeException(), isNull);
      expect(find.text('INV-YESTERDAY'), findsOneWidget);
      expect(find.text('INV-TODAY'), findsNothing);
    },
  );

  testWidgets(
    'load failures surface an error state with a retry action',
    (tester) async {
      final deadDatabase = await tester.runAsync(() async {
        final opened = await AppDatabase.open(path: inMemoryDatabasePath);
        await opened.close();
        return opened;
      });

      await pumpApp(
        tester,
        initialRoute: AppRoutes.sales,
        saleRepositoryOverride: SaleRepository(deadDatabase!),
      );
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Sales could not be loaded'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Try again'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Try again'));
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Sales could not be loaded'), findsOneWidget);
    },
  );
}
