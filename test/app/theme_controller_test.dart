import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/app/theme_controller.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    settings = SettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('parses and encodes every theme mode', () {
    expect(ThemeController.parse(null), ThemeMode.system);
    expect(ThemeController.parse('garbage'), ThemeMode.system);
    expect(ThemeController.parse('light'), ThemeMode.light);
    expect(ThemeController.parse('dark'), ThemeMode.dark);
    expect(ThemeController.parse('system'), ThemeMode.system);
    expect(ThemeController.encode(ThemeMode.light), 'light');
    expect(ThemeController.encode(ThemeMode.dark), 'dark');
    expect(ThemeController.encode(ThemeMode.system), 'system');
  });

  test('defaults to system and restores the persisted mode on load', () async {
    final fresh = ThemeController(settings);
    expect(fresh.mode, ThemeMode.system);
    await fresh.load();
    expect(fresh.mode, ThemeMode.system);

    await fresh.setMode(ThemeMode.dark);
    expect(fresh.mode, ThemeMode.dark);
    expect(await settings.getString(ThemeController.settingsKey), 'dark');

    final restored = ThemeController(settings);
    await restored.load();
    expect(restored.mode, ThemeMode.dark);
  });
}
