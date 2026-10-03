import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:qubexcore_pos/app/auth_gate.dart';
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/security/pin_hasher.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/test_pin_iterations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<AppDatabase> openSeededDatabase({
    String username = 'admin',
    String pin = '1234',
    bool mustChangePin = true,
  }) async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    await db.db.insert('staff_users', {
      'uuid': 'uuid-$username',
      'username': username,
      'display_name': 'Store Admin',
      'role': 'admin',
      'password_hash':
          await PinHasher.hash(pin, iterations: kTestPinIterations),
      'must_change_pin': mustChangePin ? 1 : 0,
      'is_active': 1,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
    return db;
  }

  Future<void> pumpGate(WidgetTester tester, AppDatabase database) async {
    final List<SingleChildWidget> providers =
        buildAppProviders(database, pinIterations: kTestPinIterations);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: MaterialApp(
            theme: QubeXCoreTheme.light(),
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const AuthGate(),
          ),
        ),
      );
    });
    await tester.pump();
    await tester.pump();
  }

  // Sign-in performs real async work: a sqflite FFI read plus PBKDF2. Neither
  // completes under FakeAsync, so the tap and the wait must run inside
  // tester.runAsync, then the result is rendered with a normal pump.
  Future<void> tapAndSettle(
    WidgetTester tester,
    Finder finder, {
    bool Function()? until,
    int maxPolls = 300,
  }) async {
    await tester.runAsync(() async {
      await tester.tap(finder, warnIfMissed: false);
      for (var i = 0; i < maxPolls; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (until != null && until()) return;
      }
    });
    await tester.pump();
  }

  testWidgets('gate shows the login screen while signed out', (tester) async {
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

    await pumpGate(tester, database);

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('PIN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Enter demo mode'), findsNothing);
  });

  testWidgets('wrong pin shows an error and stays on login', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase database;
    await tester.runAsync(() async {
      database = await openSeededDatabase();
    });
    addTearDown(() async {
      await tester.runAsync(database.close);
    });

    await pumpGate(tester, database);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '0000');
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Sign in'),
      until: () => find.text('Incorrect username or PIN').evaluate().isNotEmpty,
    );

    expect(find.text('Incorrect username or PIN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('seed admin is forced to change the pin before selling',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase database;
    await tester.runAsync(() async {
      database = await openSeededDatabase();
    });
    addTearDown(() async {
      await tester.runAsync(database.close);
    });

    await pumpGate(tester, database);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Sign in'),
      until: () => find.text('Change PIN').evaluate().isNotEmpty,
    );

    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.enterText(find.byType(TextFormField).at(0), '1234');
    await tester.enterText(find.byType(TextFormField).at(1), '9876');
    await tester.enterText(find.byType(TextFormField).at(2), '9876');
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Save new PIN'),
      until: () => find.byType(NavigationBar).evaluate().isNotEmpty,
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.text('New Sale'), findsWidgets);
  });

  testWidgets('a user without mustChangePin reaches the shell directly',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    late AppDatabase database;
    await tester.runAsync(() async {
      database = await openSeededDatabase(mustChangePin: false);
    });
    addTearDown(() async {
      await tester.runAsync(database.close);
    });

    await pumpGate(tester, database);

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), '1234');
    await tapAndSettle(
      tester,
      find.widgetWithText(ElevatedButton, 'Sign in'),
      until: () => find.byType(NavigationBar).evaluate().isNotEmpty,
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Change PIN'), findsNothing);

    // The dashboard runs two chained sqflite reads after the shell mounts:
    // give each a real window, then flush its continuation with a pump so no
    // query is still pending when the test tears down.
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pump();
    }
    expect(find.text('New Sale'), findsWidgets);
  });
}
