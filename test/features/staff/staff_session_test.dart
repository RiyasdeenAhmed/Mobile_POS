import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/security/pin_hasher.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
import 'package:qubexcore_pos/features/staff/data/staff_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/test_pin_iterations.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late StaffRepository repository;
  late StaffSession session;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = StaffRepository(db);
    session = StaffSession()..attach(repository);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedUser({
    String username = 'admin',
    String role = 'admin',
    String pin = '1234',
    bool mustChangePin = false,
  }) async {
    await db.db.insert('staff_users', {
      'uuid': 'uuid-$username',
      'username': username,
      'display_name': 'Test $username',
      'role': role,
      'password_hash':
          await PinHasher.hash(pin, iterations: kTestPinIterations),
      'must_change_pin': mustChangePin ? 1 : 0,
      'is_active': 1,
      'is_archived': 0,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
  }

  test('starts signed out', () {
    expect(session.isSignedIn, isFalse);
    expect(session.current, isNull);
    expect(session.staffUuid, isNull);
    expect(session.isAdmin, isFalse);
    expect(session.mustChangePin, isFalse);
  });

  test('signIn stores the user and exposes the role', () async {
    await seedUser(role: 'admin');
    var notifications = 0;
    session.addListener(() => notifications++);

    final result = await session.signIn(username: 'admin', pin: '1234');

    expect(result.isSuccess, isTrue);
    expect(session.isSignedIn, isTrue);
    expect(session.staffUuid, 'uuid-admin');
    expect(session.displayName, 'Test admin');
    expect(session.isAdmin, isTrue);
    expect(session.mustChangePin, isFalse);
    expect(notifications, greaterThan(0));
  });

  test('signIn marks a non admin as not admin', () async {
    await seedUser(username: 'cashier', role: 'cashier');
    await session.signIn(username: 'cashier', pin: '1234');
    expect(session.isAdmin, isFalse);
  });

  test('signIn does not sign in with a wrong pin', () async {
    await seedUser();
    final result = await session.signIn(username: 'admin', pin: '0000');
    expect(result.isFailure, isTrue);
    expect(session.isSignedIn, isFalse);
    expect(session.staffUuid, isNull);
  });

  test('signIn surfaces mustChangePin from the seed account', () async {
    await seedUser(mustChangePin: true);
    final result = await session.signIn(username: 'admin', pin: '1234');
    expect(result.isSuccess, isTrue);
    expect(session.mustChangePin, isTrue);
  });

  test('changePin rotates the pin and clears mustChangePin', () async {
    await seedUser(mustChangePin: true);
    await session.signIn(username: 'admin', pin: '1234');

    final result = await session.changePin(currentPin: '1234', newPin: '9876');

    expect(result.isSuccess, isTrue);
    expect(session.mustChangePin, isFalse);
    session.signOut();

    final again = await session.signIn(username: 'admin', pin: '9876');
    expect(again.isSuccess, isTrue);
  });

  test('changePin fails on a wrong current pin', () async {
    await seedUser();
    await session.signIn(username: 'admin', pin: '1234');

    final result = await session.changePin(currentPin: '9999', newPin: '9876');

    expect(result.isFailure, isTrue);
    expect(session.mustChangePin, isFalse);
    final verify = await session.signIn(username: 'admin', pin: '1234');
    expect(verify.isSuccess, isTrue);
  });

  test('signOut clears the session', () async {
    await seedUser();
    await session.signIn(username: 'admin', pin: '1234');
    var notifications = 0;
    session.addListener(() => notifications++);

    session.signOut();

    expect(session.isSignedIn, isFalse);
    expect(session.staffUuid, isNull);
    expect(notifications, 1);
  });

  test('signOut on a signed out session notifies nothing', () {
    var notifications = 0;
    session.addListener(() => notifications++);
    session.signOut();
    expect(notifications, 0);
  });

  test('signIn fails when no repository is attached', () async {
    final detached = StaffSession();
    final result = await detached.signIn(username: 'admin', pin: '1234');
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'unavailable');
  });

  test('changePin fails when not signed in', () async {
    final result = await session.changePin(currentPin: '1234', newPin: '9876');
    expect(result.isFailure, isTrue);
    expect(result.failureOrNull?.code, 'unavailable');
  });

  test('adopt replaces the current user', () async {
    await seedUser();
    final user = await repository.findByUsername('admin');
    session.adopt(user!);
    expect(session.isSignedIn, isTrue);
    expect(session.staffUuid, 'uuid-admin');
  });
}
