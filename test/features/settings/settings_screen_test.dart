import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/core/theme/money_text.dart';
import 'package:qubexcore_pos/features/settings/presentation/settings_screen.dart';
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

  setUp(() {
    MoneyFormat.defaultSymbol = 'Rs';
    addTearDown(() => MoneyFormat.defaultSymbol = 'Rs');
  });

  late AppDatabase db;
  late SettingsRepository settings;

  Future<void> openDb(WidgetTester tester) async {
    await realAsync(tester, () async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      settings = SettingsRepository(db);
    });
    addTearDown(() => tester.runAsync(db.close));
  }

  Widget app() {
    return MultiProvider(
      providers: [Provider<SettingsRepository>.value(value: settings)],
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  Future<void> pumpLoaded(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldByLabel(String label) => find.widgetWithText(
        TextFormField,
        label,
      );

  testWidgets('validates required fields and saves settings', (tester) async {
    await openDb(tester);
    await pumpLoaded(tester);
    expect(fieldByLabel('Name'), findsOneWidget);
    expect(fieldByLabel('Tax rate (%)'), findsOneWidget);

    await tester.enterText(fieldByLabel('Name'), '');
    await tester.tap(find.text('Save settings'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Store name is required'), findsOneWidget);

    await tester.enterText(fieldByLabel('Tax rate (%)'), '150');
    await tester.tap(find.text('Save settings'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Must be between 0 and 100'), findsOneWidget);

    await tester.enterText(fieldByLabel('Name'), 'Corner Shop');
    await tester.enterText(fieldByLabel('Tax rate (%)'), '7.5');
    await tester.tap(find.text('Save settings'));
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings saved'), findsOneWidget);

    final storedName =
        await realAsync(tester, () => settings.getString('store_name'));
    final storedTax =
        await realAsync(tester, () => settings.getString('tax_rate_bps'));
    expect(storedName, 'Corner Shop');
    expect(storedTax, '750');
    expect(MoneyFormat.defaultSymbol, 'Rs');
  });

  testWidgets('persists printer and negative-stock toggles', (tester) async {
    await openDb(tester);
    await pumpLoaded(tester);

    await tester.ensureVisible(find.text('Allow negative stock'));
    await tester.pump();
    await tester.tap(find.text('Allow negative stock'));
    await tester.pump();
    await tester.ensureVisible(find.text('Auto-print receipts'));
    await tester.pump();
    await tester.tap(find.text('Auto-print receipts'));
    await tester.pump();

    await tester.ensureVisible(find.text('Save settings'));
    await tester.pump();
    await tester.tap(find.text('Save settings'));
    await realAsync(
      tester,
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settings saved'), findsOneWidget);

    final negative = await realAsync(
        tester, () => settings.getString('allow_negative_stock'));
    final autoPrint =
        await realAsync(tester, () => settings.getString('auto_print_receipt'));
    expect(negative, '1');
    expect(autoPrint, '1');
  });
}
