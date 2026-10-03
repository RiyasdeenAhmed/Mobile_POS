import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/main_shell.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('main shell shows dashboard and navigates primary tabs',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase database;
    await tester.runAsync(() async {
      database = await AppDatabase.open(path: inMemoryDatabasePath);
    });
    addTearDown(() async {
      await tester.runAsync(database.close);
    });

    final List<SingleChildWidget> providers = buildAppProviders(database);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            theme: QubeXCoreTheme.light(),
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const MainShell(),
          ),
        ),
      );
    });
    await tester.pump();
    await tester.pump();

    expect(find.text('New Sale'), findsWidgets);
    expect(find.text('Quick actions'), findsOneWidget);

    final navBar = find.byType(NavigationBar);
    await tester.runAsync(() async {
      await tester.tap(
        find.descendant(of: navBar, matching: find.text('Sales')),
        warnIfMissed: false,
      );
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
    await tester.pump();
    expect(find.text('No sales yet'), findsOneWidget);

    await tester.tap(
      find.descendant(of: navBar, matching: find.text('More')),
      warnIfMissed: false,
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Inventory'), findsOneWidget);
  });
}
