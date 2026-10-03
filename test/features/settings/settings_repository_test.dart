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
}
