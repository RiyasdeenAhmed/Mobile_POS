import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/widgets/app_snack.dart';
import 'package:qubexcore_pos/features/categories/data/category_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/presentation/checkout_screen.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_controller.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/pos/presentation/cart_screen.dart';
import 'package:qubexcore_pos/features/pos/presentation/new_sale_screen.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// sqflite FFI work is real async: every DB call runs inside tester.runAsync,
// then the result is rendered with the fake clock (pattern from
// auth_gate_test and the product form widget tests).
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
  late CustomerRepository customers;
  late CartController cart;

  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    products = ProductRepository(db);
    categories = CategoryRepository(db);
    customers = CustomerRepository(db);
    cart = CartController();
    addTearDown(() => tester.runAsync(db.close));
  }

  /// Pumps [screen] wrapped in the providers it needs, gives the real async
  /// load a window, then renders.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget screen,
    bool withCheckout = false,
    bool withCustomerRepo = false,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: products),
            Provider<CategoryRepository>.value(value: categories),
            ChangeNotifierProvider<CartController>.value(value: cart),
            if (withCheckout) ...[
              Provider<SettingsRepository>.value(value: SettingsRepository(db)),
              Provider<CustomerRepository>.value(value: customers),
              Provider<CheckoutService>.value(value: CheckoutService(db)),
              ChangeNotifierProvider<StaffSession>.value(value: StaffSession()),
            ],
          ],
          child: MaterialApp(home: screen),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
  }

  /// Lets a visible snackbar finish its auto-dismiss so the next one
  /// does not sit queued behind it.
  Future<void> clearSnackbars(WidgetTester tester) async {
    // Finish the entrance animation (the auto-dismiss timer only starts
    // when it completes), fire the longest centralized duration, then run
    // the dismissal.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(
      AppSnackDurations.error + const Duration(milliseconds: 100),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('New Sale: category chips filter products and caps additions',
      (tester) async {
    usePhoneSurface(tester);
    await openDb(tester);

    final drinks = await realAsync(
      tester,
      () async => (await categories.create(name: 'Drinks')).dataOrNull!,
    );
    await realAsync(tester, () async {
      await products.create(
        name: 'Cola',
        categoryId: drinks.id,
        stockQuantity: 5,
        sellingPriceMinor: 300,
      );
      await products.create(
        name: 'Chips',
        stockQuantity: 2,
        sellingPriceMinor: 150,
      );
      await products.create(
        name: 'Water',
        categoryId: drinks.id,
        stockQuantity: 0,
        sellingPriceMinor: 100,
      );
    });

    await pumpScreen(tester, screen: const NewSaleScreen());

    // All products visible with the All chip selected.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Drinks'), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Chips'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Pay'), findsOneWidget);
    expect(find.text('Checkout'), findsNothing);

    // Filter by category.
    await tester.tap(find.text('Drinks'));
    await tester.pumpAndSettle();
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Chips'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Chips'), findsOneWidget);

    // Add twice (stock is 2), third add is blocked with a message.
    await tester.tap(find.text('Chips'));
    await tester.pump();
    expect(find.text('Added Chips'), findsOneWidget);
    expect(cart.itemCount, 1);

    await clearSnackbars(tester);
    await tester.tap(find.text('Chips'));
    await tester.pump();
    expect(cart.items.single.quantity, 2);

    await clearSnackbars(tester);
    await tester.tap(find.text('Chips'));
    await tester.pump();
    expect(find.text('Only 2 in stock'), findsOneWidget);
    expect(cart.items.single.quantity, 2);

    // Out-of-stock product cannot be added.
    await tester.tap(find.text('Water'));
    await tester.pump();
    expect(cart.items.single.productName, 'Chips');
  });

  testWidgets('Cart: stepper caps at stock, discount and note work',
      (tester) async {
    usePhoneSurface(tester);
    await openDb(tester);

    final product = (await realAsync(
      tester,
      () async => (await products.create(
        name: 'Espresso',
        stockQuantity: 1,
        sellingPriceMinor: 500,
      ))
          .dataOrNull!,
    ));
    cart.addItem(CartItem.fromProduct(product));

    await pumpScreen(tester, screen: const CartScreen());

    // Quantity 1 = stock cap: the increase button must be disabled.
    final increase = tester.widget<IconButton>(
      find
          .ancestor(
            of: find.byTooltip('Increase'),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(increase.onPressed, isNull);
    expect(
      find.text('Maximum stock reached'),
      findsOneWidget,
    );

    // Discount dialog writes a line discount.
    await tester.tap(find.widgetWithText(TextButton, 'Discount'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '0.50',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Discount'), findsWidgets);
    expect(cart.discountMinor, 50);
    expect(cart.totalMinor, 450);

    // Order note flows into the controller.
    await tester.enterText(
      find.widgetWithText(TextField, 'Order note (optional)'),
      'Pack separately',
    );
    await tester.pump();
    expect(cart.note, 'Pack separately');

    expect(find.widgetWithText(FilledButton, 'Proceed to Checkout'),
        findsOneWidget);
  });

  testWidgets('Checkout validates split allocation and cash tender',
      (tester) async {
    usePhoneSurface(tester);
    await openDb(tester);
    final product = await realAsync(
        tester,
        () async => (await products.create(
                name: 'Tea', sellingPriceMinor: 1200, stockQuantity: 5))
            .dataOrNull!);
    cart.addItem(CartItem.fromProduct(product));
    await pumpScreen(tester,
        screen: const CheckoutScreen(), withCheckout: true);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Split'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Split'));
    await tester.pumpAndSettle();
    Future<void> amount(String label, String value) async {
      final field = find.widgetWithText(TextField, label);
      await tester.scrollUntilVisible(field, 160,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(field, value);
      await tester.pump();
    }

    await amount('Cash amount', '5.00');
    await amount('QR amount', '7.00');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Complete sale'))
            .onPressed,
        isNull);
    await amount('Cash received', '10.00');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Complete sale'))
            .onPressed,
        isNotNull);
    await amount('Cash received', 'bad');
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Complete sale'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Checkout: walk-in is the default customer', (tester) async {
    usePhoneSurface(tester);
    await openDb(tester);

    final product = (await realAsync(
      tester,
      () async =>
          (await products.create(name: 'Bun', stockQuantity: 4)).dataOrNull!,
    ));
    cart.addItem(CartItem.fromProduct(product));
    await realAsync(
      tester,
      () async => (await customers.create(
        name: 'Acme Cafe',
        creditLimitMinor: 50000,
      ))
          .dataOrNull!,
    );

    await pumpScreen(
      tester,
      screen: const CheckoutScreen(),
      withCheckout: true,
    );

    await tester.scrollUntilVisible(find.text('Walk-in customer'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Walk-in customer'), findsOneWidget);
    expect(find.text('No customer account — cash sale'), findsOneWidget);

    // The customer card lives in a ListView: scroll it into view first.
    await tester
        .ensureVisible(find.widgetWithText(ListTile, 'Walk-in customer'));
    await tester.pumpAndSettle();

    // Open the picker: walk-in is offered alongside real customers.
    await tester.runAsync(() async {
      await tester.tap(find.text('Walk-in customer'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('Acme Cafe'), findsOneWidget);

    await tester.tap(find.text('Walk-in customer').last);
    await tester.pumpAndSettle();
    // Modal sheet futures only resolve on a real event-loop turn under the
    // fake-async test binding: give the pending await a real window.
    await realAsync(tester, customers.list);
    await tester.pumpAndSettle();
    expect(find.text('No customer account — cash sale'), findsOneWidget);

    // Selecting a real customer updates the tile.
    await tester.ensureVisible(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.person_outline));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
    expect(find.text('Acme Cafe'), findsOneWidget);

    await tester.tap(find.text('Acme Cafe'));
    await realAsync(tester, customers.list);
    await tester.pumpAndSettle();
    expect(find.text('Acme Cafe'), findsOneWidget);
    expect(
      find.textContaining(r'Limit Rs'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Checkout credit picker only offers customers with credit enabled',
    (tester) async {
      usePhoneSurface(tester);
      await openDb(tester);

      final product = (await realAsync(
        tester,
        () async =>
            (await products.create(name: 'Cake', stockQuantity: 4)).dataOrNull!,
      ));
      cart.addItem(CartItem.fromProduct(product));
      await realAsync(tester, () async {
        await customers.create(name: 'Credit Enabled', creditLimitMinor: 50000);
        await customers.create(name: 'No Credit Here');
        await customers.create(
          name: 'Switched Off',
          creditLimitMinor: 20000,
          creditEnabled: false,
        );
      });

      await pumpScreen(
        tester,
        screen: const CheckoutScreen(),
        withCheckout: true,
      );

      // Switch to the credit method. The follow-up customer preload is a DB
      // read, so it needs a real window before the spinner can settle.
      await tester.ensureVisible(find.text('Customer credit'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Customer credit'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Walk-in customer'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Walk-in customer'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(find.text('Credit Enabled'), findsOneWidget);
      expect(find.text('No Credit Here'), findsNothing);
      expect(find.text('Switched Off'), findsNothing);

      await tester.tap(find.text('Walk-in customer').last);
      await tester.pumpAndSettle();
      await realAsync(tester, customers.list);
      await tester.pumpAndSettle();
      expect(find.text('Walk-in customer'), findsOneWidget);
    },
  );
}
