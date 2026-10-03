import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import '../utils/time_utils.dart';

class SettingsRepository {
  final AppDatabase database;

  SettingsRepository(this.database);

  Future<String?> getString(String key) async {
    final rows = await database.db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final value = rows.first['value'];
    return value?.toString();
  }

  Future<String> getStringOrDefault(String key, String defaultValue) async {
    final value = await getString(key);
    return value ?? defaultValue;
  }

  Future<void> setString(String key, String value) async {
    await database.db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'updated_at': utcNowIso(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> ensureSeededDefaults() async {
    const defaults = <String, String>{
      'store_name': 'QubeXCore Store',
      'currency_symbol': r'$',
      'currency_code': 'USD',
      'invoice_sequence': '0',
    };
    for (final entry in defaults.entries) {
      final existing = await getString(entry.key);
      if (existing == null) {
        await setString(entry.key, entry.value);
      }
    }
  }

  Future<Map<String, String>> loadCoreSettings() async {
    const keys = [
      'store_name',
      'currency_symbol',
      'currency_code',
      'invoice_sequence',
    ];
    final result = <String, String>{};
    for (final key in keys) {
      result[key] = await getString(key) ?? '';
    }
    return result;
  }
}
