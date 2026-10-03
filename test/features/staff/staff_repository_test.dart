import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/security/pin_hasher.dart';
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

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = StaffRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedUser({
    String username = 'cashier1',
    String role = 'cashier',
    String? hash,
    bool archived = false,
    bool active = true,
  }) async {
    await db.db.insert('staff_users', {
      'uuid': 'uuid-$username',
      'username': username,
      'display_name': username,
      'role': role,
      'password_hash': hash,
      'must_change_pin': 0,
      'is_active': active ? 1 : 0,
      'is_archived': archived ? 1 : 0,
      'created_at': '2026-01-01T00:00:00.000Z',
      'updated_at': '2026-01-01T00:00:00.000Z',
    });
  }

  Future<String> fastHash() async =>
      PinHasher.hash('1234', iterations: kTestPinIterations);

  group('verifyPin', () {
    test('succeeds with the correct pin', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final result = await repository.verifyPin(
        username: 'cashier1',
        pin: '1234',
      );

      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.username, 'cashier1');
    });

    test('fails with an incorrect pin', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final result = await repository.verifyPin(
        username: 'cashier1',
        pin: '9999',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'invalid_credentials');
    });

    test('does not reveal whether the username exists', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final wrongUser = await repository.verifyPin(
        username: 'nobody',
        pin: '1234',
      );
      final wrongPin = await repository.verifyPin(
        username: 'cashier1',
        pin: '0000',
      );

      expect(wrongUser.failureOrNull?.message, 'Incorrect username or PIN');
      expect(wrongPin.failureOrNull?.message, wrongUser.failureOrNull?.message);
    });

    test('rejects an archived account', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash, archived: true);

      final result = await repository.verifyPin(
        username: 'cashier1',
        pin: '1234',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'inactive_account');
    });

    test('rejects a deactivated account', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash, active: false);

      final result = await repository.verifyPin(
        username: 'cashier1',
        pin: '1234',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'inactive_account');
    });

    test('rejects an account with no pin set', () async {
      await seedUser();

      final result = await repository.verifyPin(
        username: 'cashier1',
        pin: '1234',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, contains('no PIN set'));
    });

    test('trims the username', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final result = await repository.verifyPin(
        username: '  cashier1  ',
        pin: '1234',
      );

      expect(result.isSuccess, isTrue);
    });

    test('requires a username and pin', () async {
      expect(
          (await repository.verifyPin(username: '  ', pin: '1234'))
              .failureOrNull
              ?.code,
          'validation');
      expect(
          (await repository.verifyPin(username: 'a', pin: ''))
              .failureOrNull
              ?.code,
          'validation');
    });
  });

  group('setPin and changePin', () {
    test('setPin stores a hash and clears must_change_pin', () async {
      await seedUser();
      await db.db.update(
        'staff_users',
        {'must_change_pin': 1},
        where: 'username = ?',
        whereArgs: ['cashier1'],
      );

      final result = await repository.setPin(
        uuid: 'uuid-cashier1',
        newPin: '4321',
      );

      expect(result.isSuccess, isTrue);
      final stored = await repository.findByUsername('cashier1');
      expect(stored?.passwordHash, isNot('4321'));
      expect(stored?.mustChangePin, isFalse);
      final verify =
          await repository.verifyPin(username: 'cashier1', pin: '4321');
      expect(verify.isSuccess, isTrue);
    });

    test('setPin rejects a pin that is too short', () async {
      await seedUser();
      final result =
          await repository.setPin(uuid: 'uuid-cashier1', newPin: '12');
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'validation');
    });

    test('setPin rejects a non numeric pin', () async {
      await seedUser();
      final result =
          await repository.setPin(uuid: 'uuid-cashier1', newPin: 'abcd');
      expect(result.isFailure, isTrue);
    });

    test('setPin rejects a pin longer than the maximum', () async {
      await seedUser();
      final result =
          await repository.setPin(uuid: 'uuid-cashier1', newPin: '123456789');
      expect(result.isFailure, isTrue);
    });

    test('setPin fails for an unknown uuid', () async {
      final result = await repository.setPin(uuid: 'nope', newPin: '1234');
      expect(result.failureOrNull?.code, 'not_found');
    });

    test('changePin requires the correct current pin', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final result = await repository.changePin(
        uuid: 'uuid-cashier1',
        currentPin: '9999',
        newPin: '5555',
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.message, 'Current PIN is incorrect');
      final stillOld =
          await repository.verifyPin(username: 'cashier1', pin: '1234');
      expect(stillOld.isSuccess, isTrue);
    });

    test('changePin rotates the pin', () async {
      final hash = await PinHasher.hash('1234', iterations: kTestPinIterations);
      await seedUser(hash: hash);

      final result = await repository.changePin(
        uuid: 'uuid-cashier1',
        currentPin: '1234',
        newPin: '5555',
      );

      expect(result.isSuccess, isTrue);
      expect(
        (await repository.verifyPin(username: 'cashier1', pin: '5555'))
            .isSuccess,
        isTrue,
      );
      expect(
        (await repository.verifyPin(username: 'cashier1', pin: '1234'))
            .isFailure,
        isTrue,
      );
    });

    test('isValidPinFormat accepts 4 to 8 digits', () {
      expect(StaffRepository.isValidPinFormat('1234'), isTrue);
      expect(StaffRepository.isValidPinFormat('12345678'), isTrue);
      expect(StaffRepository.isValidPinFormat('123'), isFalse);
      expect(StaffRepository.isValidPinFormat('123456789'), isFalse);
      expect(StaffRepository.isValidPinFormat('12a4'), isFalse);
    });
  });

  group('pinIterations injection', () {
    test('writes hashes with the injected work factor', () async {
      final injected = StaffRepository(db, pinIterations: kTestPinIterations);
      await seedUser();

      final result =
          await injected.setPin(uuid: 'uuid-cashier1', newPin: '4321');
      expect(result.isSuccess, isTrue);

      final stored = await injected.findByUsername('cashier1');
      final encoded = stored!.passwordHash!;
      expect(encoded.split(r'$')[2], '$kTestPinIterations');
      expect(
          (await injected.verifyPin(username: 'cashier1', pin: '4321'))
              .isSuccess,
          isTrue);
    });

    test('verification honours the stored count, not the repository setting',
        () async {
      // Hash written with the production default.
      final slow = await PinHasher.hash('9999');
      expect(slow.split(r'$')[2], '$defaultIterations');
      await seedUser(hash: await fastHash());

      final fastRepo = StaffRepository(db, pinIterations: kTestPinIterations);
      expect(
          (await fastRepo.verifyPin(username: 'cashier1', pin: '1234'))
              .isSuccess,
          isTrue);
    });

    test('default constructor keeps the production work factor', () async {
      expect(StaffRepository(db).pinIterations, defaultIterations);
    });
  });

  group('update and archive', () {
    test('update changes display name and role', () async {
      await seedUser();
      final result = await repository.update(
        uuid: 'uuid-cashier1',
        displayName: 'Nuwan Perera',
        role: 'admin',
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.displayName, 'Nuwan Perera');
      expect(result.dataOrNull?.role, 'admin');
    });

    test('update rejects an invalid role', () async {
      await seedUser();
      final result = await repository.update(
        uuid: 'uuid-cashier1',
        displayName: 'Nuwan',
        role: 'superuser',
      );
      expect(result.isFailure, isTrue);
    });

    test('archive deactivates and can be reversed', () async {
      await seedUser();
      final archived =
          await repository.setArchived(uuid: 'uuid-cashier1', archived: true);
      expect(archived.dataOrNull?.isArchived, isTrue);
      expect(archived.dataOrNull?.isActive, isFalse);

      final restored =
          await repository.setArchived(uuid: 'uuid-cashier1', archived: false);
      expect(restored.dataOrNull?.isArchived, isFalse);
      expect(restored.dataOrNull?.isActive, isTrue);
    });

    test('isLastActiveAdmin guards the final admin', () async {
      await seedUser(username: 'admin1', role: 'admin');
      expect(await repository.isLastActiveAdmin('uuid-admin1'), isTrue);

      await seedUser(username: 'admin2', role: 'admin');
      expect(await repository.isLastActiveAdmin('uuid-admin1'), isFalse);
    });

    test('isLastActiveAdmin is false for a non admin', () async {
      await seedUser();
      expect(await repository.isLastActiveAdmin('uuid-cashier1'), isFalse);
    });
  });

  group('create', () {
    test('creates a cashier without a pin', () async {
      final result = await repository.create(
        username: 'newuser',
        displayName: 'New User',
      );
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.role, 'cashier');
      expect(result.dataOrNull?.mustChangePin, isFalse);
    });

    test('rejects a duplicate username', () async {
      await seedUser();
      final result = await repository.create(
        username: 'cashier1',
        displayName: 'Duplicate',
      );
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull?.code, 'duplicate_username');
    });

    test('rejects an empty display name', () async {
      final result = await repository.create(
        username: 'blank',
        displayName: '   ',
      );
      expect(result.failureOrNull?.code, 'validation');
    });
  });

  group('list', () {
    test('excludes archived staff by default', () async {
      await seedUser(username: 'a1');
      await seedUser(username: 'a2', archived: true);

      expect(await repository.list(), hasLength(1));
      expect(await repository.list(includeArchived: true), hasLength(2));
    });
  });
}
