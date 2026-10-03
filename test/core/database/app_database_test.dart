import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/migrations.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('schema version is 4 and core tables exist', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    expect(AppDatabase.schemaVersion, 4);

    final rows = await db.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = rows.map((row) => row['name'] as String).toSet();
    const expected = {
      'schema_migrations',
      'app_settings',
      'staff_users',
      'products',
      'categories',
      'customers',
      'sales',
      'sale_items',
      'payments',
      'stock_movements',
      'customer_ledger',
    };
    for (final table in expected) {
      expect(names.contains(table), isTrue, reason: 'missing $table');
    }
    await db.close();
  });

  test('foreign keys are enabled', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    expect(await db.areForeignKeysEnabled(), isTrue);
    await db.close();
  });

  test('settings are seeded and schema migration recorded', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final settings = SettingsRepository(db);
    expect(await settings.getString('store_name'), 'QubeXCore Store');
    expect(await settings.getString('currency_symbol'), 'Rs');
    expect(await settings.getString('currency_code'), 'LKR');
    expect(await settings.getString('invoice_sequence'), '0');
    expect(await settings.getString('invoice_prefix'), 'INV');

    final migrations = await db.db.query('schema_migrations');
    final versions = migrations.map((row) => row['version']).toSet();
    expect(versions, containsAll(<int>[1, 2]));
    await db.close();
  });

  test('migration v2 adds must_change_pin to staff_users', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    final columns = await db.db.rawQuery('PRAGMA table_info(staff_users)');
    final names = columns.map((row) => row['name'] as String).toSet();
    expect(names, contains('must_change_pin'));
    await db.close();
  });

  test('data persists across reopen', () async {
    final tempDir = await Directory.systemTemp.createTemp('qubex_db_test');
    final path = p.join(tempDir.path, 'qubexcore.db');
    final first = await AppDatabase.open(path: path);
    final settings = SettingsRepository(first);
    await settings.setString('store_name', 'Persisted Store');
    await first.close();

    final second = await AppDatabase.open(path: path);
    final reopened = SettingsRepository(second);
    expect(await reopened.getString('store_name'), 'Persisted Store');
    await second.close();
    await tempDir.delete(recursive: true);
  });

  test('existing v1 install upgrades through v2, v3 and v4 on open', () async {
    final tempDir = await Directory.systemTemp.createTemp('qubex_db_upgrade');
    final path = p.join(tempDir.path, 'qubexcore.db');
    final v1 = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await MigrationRunner.ensureSchemaMigrationsTable(db);
          await MigrationRunner.applyPending(db, 1);
        },
      ),
    );
    expect(await MigrationRunner.appliedVersions(v1), {1});
    await v1.close();

    final upgraded = await AppDatabase.open(path: path);
    expect(
      await MigrationRunner.appliedVersions(upgraded.db),
      {1, 2, 3, 4},
    );
    await upgraded.close();
    await tempDir.delete(recursive: true);
  });
}
