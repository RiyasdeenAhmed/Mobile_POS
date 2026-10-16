import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/money_text.dart';
import 'package:qubexcore_pos/features/customers/data/customer_ledger_repository.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/customers/data/repayment_service.dart';
import 'package:qubexcore_pos/features/customers/domain/customer.dart';
import 'package:qubexcore_pos/features/customers/presentation/customer_account_screen.dart';
import 'package:qubexcore_pos/features/customers/presentation/customer_form_screen.dart';
import 'package:qubexcore_pos/features/customers/presentation/customers_screen.dart';
import 'package:qubexcore_pos/core/utils/id_generator.dart';
import 'package:qubexcore_pos/core/utils/time_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  late CustomerRepository customers;
  late CustomerLedgerRepository ledger;
  late RepaymentService repayments;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    customers = CustomerRepository(db);
    ledger = CustomerLedgerRepository(db);
    repayments = RepaymentService(db);
    addTearDown(() => tester.runAsync(db.close));
  }

  // Fixture DB calls run inside realAsync: testWidgets bodies use a fake
  // event loop where sqflite FFI futures would never complete.
  Future<Customer> createCustomer(
    WidgetTester tester,
    String name, {
    int creditLimitMinor = 0,
  }) async {
    return realAsync(tester, () async {
      final result = await customers.create(
        name: name,
        creditLimitMinor: creditLimitMinor,
      );
      return result.dataOrNull!;
    });
  }

  Future<void> seedDebt(
    WidgetTester tester,
    Customer customer,
    int amountMinor,
  ) async {
    await realAsync(tester, () async {
      final now = utcNowIso();
      final newBalance = customer.balanceMinor + amountMinor;
      await db.db.insert(
        'customer_ledger',
        {
          'uuid': newBusinessId(),
          'customer_id': customer.id,
          'entry_type': 'debt_sale',
          'amount_minor': amountMinor,
          'balance_after_minor': newBalance,
          'sale_uuid': newBusinessId(),
          'sale_id': null,
          'note': null,
          'staff_uuid': null,
          'created_at': now,
        },
      );
      await db.db.update(
        'customers',
        {'balance_minor': newBalance, 'updated_at': now},
        where: 'uuid = ?',
        whereArgs: [customer.uuid],
      );
    });
  }

  Widget app(Widget screen) {
    return MultiProvider(
      providers: [
        Provider<CustomerRepository>.value(value: customers),
        Provider<CustomerLedgerRepository>.value(value: ledger),
        Provider<RepaymentService>.value(value: repayments),
      ],
      child: MaterialApp(home: screen),
    );
  }

  /// Taps a dialog action. Dialog route futures only settle their
  /// continuation on a real event-loop turn, and the follow-up DB work is
  /// real async: tap in a real window, finish the route animation with fake
  /// pumps, then run the continuation in a second real window.
  Future<void> confirmDialogAction(
    WidgetTester tester,
    Finder action,
  ) async {
    await tester.runAsync(() async {
      await tester.tap(action);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
  }

  Future<void> pumpApp(
    WidgetTester tester,
    Widget screen, {
    Duration delay = const Duration(milliseconds: 400),
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(screen));
      await Future<void>.delayed(delay);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('account screen shows balance, credit limit, and ledger entry',
      (tester) async {
    await openDb(tester);
    final customer = await createCustomer(
      tester,
      'Acme Cafe',
      creditLimitMinor: 50000,
    );
    await seedDebt(tester, customer, 5000);

    await pumpApp(
      tester,
      CustomerAccountScreen(customerUuid: customer.uuid),
    );

    expect(find.text('Acme Cafe'), findsOneWidget);
    expect(find.text(MoneyFormat.format(5000)), findsOneWidget);
    expect(
      find.text('Credit limit: ${MoneyFormat.format(50000)}'),
      findsOneWidget,
    );
    expect(find.text('Credit sale'), findsOneWidget);
    expect(find.text('Record repayment'), findsOneWidget);
  });

  testWidgets('record repayment updates balance and adds a ledger row',
      (tester) async {
    await openDb(tester);
    final customer = await createCustomer(tester, 'Acme Cafe');
    await seedDebt(tester, customer, 5000);

    await pumpApp(
      tester,
      CustomerAccountScreen(customerUuid: customer.uuid),
    );
    expect(find.text(MoneyFormat.format(5000)), findsOneWidget);

    await tester.tap(find.text('Record repayment'));
    await tester.pumpAndSettle();
    expect(find.text('Record repayment'), findsNWidgets(2));

    await tester.enterText(
      find.widgetWithText(TextField, 'Amount'),
      '20',
    );
    await confirmDialogAction(tester, find.text('Record'));

    expect(find.textContaining('Repayment recorded'), findsOneWidget);
    expect(find.text(MoneyFormat.format(3000)), findsOneWidget);
    expect(find.text('Repayment'), findsOneWidget);

    final refreshed = await realAsync(
      tester,
      () async => (await customers.findByUuid(customer.uuid))!,
    );
    expect(refreshed.balanceMinor, 3000);
    final entries = await realAsync(
      tester,
      () => ledger.listByCustomer(refreshed.id!),
    );
    expect(entries, hasLength(2));
    expect(entries.first.entryType, 'repayment');
    expect(entries.first.amountMinor, -2000);
  });

  testWidgets('customer form edits an existing customer', (tester) async {
    await openDb(tester);
    final customer = await createCustomer(
      tester,
      'Acme Cafe',
      creditLimitMinor: 50000,
    );

    await pumpApp(
      tester,
      CustomerFormScreen(customerUuid: customer.uuid),
    );

    expect(find.text('Edit customer'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Acme Cafe'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Acme Cafe'),
      'Acme Roasters',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save customer'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    final refreshed = await realAsync(
      tester,
      () async => (await customers.findByUuid(customer.uuid))!,
    );
    expect(refreshed.name, 'Acme Roasters');
    expect(refreshed.creditLimitMinor, 50000);
  });

  testWidgets('customer form requires a limit when credit is enabled',
      (tester) async {
    await openDb(tester);

    await pumpApp(tester, const CustomerFormScreen());
    expect(find.text('New customer'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Fresh Mart',
    );

    // Enabling credit with an empty limit shows an inline error at once.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a limit or turn off Allow credit'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Credit limit (optional)'),
      '250.00',
    );
    await tester.runAsync(() async {
      await tester.tap(find.text('Save customer'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    final created = await realAsync(tester, () async {
      final rows = await db.db.query('customers');
      return rows.single;
    });
    expect(created['name'], 'Fresh Mart');
    expect(created['credit_limit_minor'], 25000);
    expect(created['credit_enabled'], 1);
  });

  testWidgets('customers screen archives a customer', (tester) async {
    await openDb(tester);
    final customer = await createCustomer(tester, 'Acme Cafe');

    await pumpApp(tester, const Scaffold(body: CustomersScreen()));
    expect(find.text('Acme Cafe'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    await confirmDialogAction(tester, find.text('Archive'));

    expect(find.textContaining('Archived Acme Cafe'), findsOneWidget);
    expect(find.text('No customers yet'), findsOneWidget);

    final refreshed = await realAsync(
      tester,
      () async => (await customers.findByUuid(customer.uuid))!,
    );
    expect(refreshed.isArchived, isTrue);
  });
}
