import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    repository = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('defaults are seeded', () async {
    expect(await repository.getString('store_name'), 'QubeXCore Store');
    expect(await repository.getStringOrDefault('currency_code', 'EUR'), 'LKR');
    await repository.ensureSeededDefaults();
    expect(await repository.getString('store_name'), 'QubeXCore Store');
  });

  test('set and get string values', () async {
    await repository.setString('store_name', 'Corner Market');
    expect(await repository.getString('store_name'), 'Corner Market');
    expect(
      await repository.getStringOrDefault('missing_key', 'fallback'),
      'fallback',
    );
  });

  test('ensureSeededDefaults renames legacy tax_rate_minor to tax_rate_bps',
      () async {
    expect(await repository.getString('tax_rate_minor'), '0');
    await repository.setString('tax_rate_minor', '18');

    await repository.ensureSeededDefaults();
    expect(await repository.getString('tax_rate_bps'), '1800');
    expect(await repository.getString('tax_rate_minor'), isNull);

    await repository.ensureSeededDefaults();
    expect(await repository.getString('tax_rate_bps'), '1800');
    expect(await repository.getString('tax_rate_minor'), isNull);
  });

  test('ensureSeededDefaults keeps an existing tax_rate_bps', () async {
    await repository.setString('tax_rate_bps', '500');
    await repository.setString('tax_rate_minor', '18');

    await repository.ensureSeededDefaults();
    expect(await repository.getString('tax_rate_bps'), '500');
    expect(await repository.getString('tax_rate_minor'), isNull);
  });

  test('ensureSeededDefaults seeds tax_rate_bps when nothing is configured',
      () async {
    await repository.ensureSeededDefaults();
    expect(await repository.getString('tax_rate_bps'), '0');
    expect(await repository.getString('tax_rate_minor'), isNull);
  });
}
