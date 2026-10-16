import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await MigrationRunner.ensureSchemaMigrationsTable(db);
    // Bring the schema to v4, as an existing install would be.
    await MigrationRunner.applyPending(db, 4);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedV4Customers() async {
    const now = '2026-01-05T10:00:00.000Z';
    await db.insert('customers', {
      'uuid': 'cust-with-limit',
      'name': 'Nimal',
      'credit_limit_minor': 50000,
      'balance_minor': 2400,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('customers', {
      'uuid': 'cust-cash-only',
      'name': 'Kamal',
      'credit_limit_minor': 0,
      'balance_minor': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  test('v5 adds credit_enabled and backfills customers with limits', () async {
    await seedV4Customers();
    expect(await MigrationRunner.appliedVersions(db), {1, 2, 3, 4});

    await MigrationRunner.applyPending(db, 5);

    expect(await MigrationRunner.appliedVersions(db), {1, 2, 3, 4, 5});

    final rows = await db.query('customers', orderBy: 'id');
    expect(rows, hasLength(2));
    for (final row in rows) {
      expect(row.keys, contains('credit_enabled'));
    }
    // The customer that was operating with a limit keeps credit access.
    expect(rows[0]['uuid'], 'cust-with-limit');
    expect(rows[0]['credit_enabled'], 1);
    // The cash-only customer stays without credit.
    expect(rows[1]['uuid'], 'cust-cash-only');
    expect(rows[1]['credit_enabled'], 0);

    // New rows default to credit off.
    final insertedId = await db.insert('customers', {
      'uuid': 'cust-new',
      'name': 'Suriya',
      'credit_limit_minor': 0,
      'created_at': '2026-01-06T10:00:00.000Z',
      'updated_at': '2026-01-06T10:00:00.000Z',
    });
    final created = (await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [insertedId],
    ))
        .single;
    expect(created['credit_enabled'], 0);

    // Existing data and referential integrity survive.
    final legacy = rows[0];
    expect(legacy['credit_limit_minor'], 50000);
    expect(legacy['balance_minor'], 2400);
    final fkErrors = await db.rawQuery('PRAGMA foreign_key_check');
    expect(fkErrors, isEmpty);
  });

  test('applyPending to v5 is idempotent', () async {
    await seedV4Customers();
    await MigrationRunner.applyPending(db, 5);
    await MigrationRunner.applyPending(db, 5);

    expect(await MigrationRunner.appliedVersions(db), {1, 2, 3, 4, 5});
    final rows = await db.query('customers', orderBy: 'id');
    expect(rows, hasLength(2));
    expect(rows[0]['credit_enabled'], 1);
  });
}
