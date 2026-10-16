import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/presentation/products_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase database;
  late ProductRepository products;

  setUp(() async {
    database = await AppDatabase.open(path: inMemoryDatabasePath);
    products = ProductRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1600);
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
            home: const ProductsScreen(),
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

  testWidgets('Delete product confirms, cancels, and preserves stock',
      (tester) async {
    final product = (await tester.runAsync(
            () => products.create(name: 'Delete me', stockQuantity: 5)))!
        .dataOrNull!;
    await pumpApp(tester);
    await waitFor(tester, () => find.text('Delete me').evaluate().isNotEmpty);
    Future<void> openDelete() async {
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete product'));
      await tester.pumpAndSettle();
    }

    await openDelete();
    expect(find.text('Delete Delete me?'), findsOneWidget);
    expect(find.widgetWithText(IconButton, 'Import CSV'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete me'), findsOneWidget);
    await openDelete();
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Delete product'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await waitFor(tester, () => find.text('Delete me').evaluate().isEmpty);
    expect(find.text('Delete me'), findsNothing);
    final archived =
        await tester.runAsync(() => products.findByUuid(product.uuid));
    expect(archived!.isArchived, isTrue);
    expect(archived.stockQuantity, 5);
  });

  testWidgets('tapping a product row opens the prefilled edit form',
      (tester) async {
    final product = (await tester.runAsync(() async {
      return (await products.create(
        name: 'Cola 500ml',
        sellingPriceMinor: 300,
        stockQuantity: 5,
      ))
          .dataOrNull!;
    }))!;

    await pumpApp(tester);
    await waitFor(tester, () => find.text('Cola 500ml').evaluate().isNotEmpty);
    expect(find.text('Cola 500ml'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Cola 500ml'), warnIfMissed: false);
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await waitFor(
      tester,
      () => find.text('Edit product').evaluate().isNotEmpty,
    );

    expect(find.text('Edit product'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Cola 500ml'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(product.uuid, isNotEmpty);
  });

  testWidgets('Add product FAB opens the new product form', (tester) async {
    await pumpApp(tester);
    await waitFor(tester, () => find.text('Add product').evaluate().isNotEmpty);

    await tester.runAsync(() async {
      await tester
          .tap(find.widgetWithText(FloatingActionButton, 'Add product'));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await waitFor(
      tester,
      () => find.text('New product').evaluate().isNotEmpty,
    );

    expect(find.text('New product'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('low-stock filter and shared status badges work together',
      (tester) async {
    await tester.runAsync(() async {
      await products.create(name: 'Chips', stockQuantity: 2, reorderLevel: 5);
      await products.create(
        name: 'Gone Biscuits',
        stockQuantity: 0,
        reorderLevel: 0,
      );
      await products.create(
        name: 'Fine Water',
        stockQuantity: 50,
        reorderLevel: 5,
      );
    });

    await pumpApp(tester);
    await waitFor(tester, () => find.text('Chips').evaluate().isNotEmpty);

    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('In Stock'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Low stock'));
    await tester.pump();

    expect(find.text('Chips'), findsOneWidget);
    expect(find.text('Gone Biscuits'), findsOneWidget);
    expect(find.text('Fine Water'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
