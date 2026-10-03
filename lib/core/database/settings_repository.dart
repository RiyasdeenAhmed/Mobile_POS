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
    // Legacy installs stored tax as `tax_rate_minor` (whole percent).
    // Convert to `tax_rate_bps` idempotently; never edit a released migration.
    final legacyTax = await getString('tax_rate_minor');
    if (legacyTax != null) {
      final existingBps = await getString('tax_rate_bps');
      if (existingBps == null) {
        final percent = int.tryParse(legacyTax) ?? 0;
        await setString('tax_rate_bps', '${percent * 100}');
      }
      await database.db.delete(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['tax_rate_minor'],
      );
    }
    const defaults = <String, String>{
      'store_name': 'QubeXCore Store',
      'currency_symbol': 'Rs',
      'currency_code': 'LKR',
      'invoice_sequence': '0',
      'invoice_prefix': 'INV',
      'receipt_footer': 'Thank you for your purchase',
      'tax_rate_bps': '0',
      'allow_negative_stock': '0',
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
      'store_address',
      'store_phone',
      'currency_symbol',
      'currency_code',
      'invoice_sequence',
      'invoice_prefix',
      'receipt_footer',
      'tax_rate_bps',
      'allow_negative_stock',
    ];
    final result = <String, String>{};
    for (final key in keys) {
      result[key] = await getString(key) ?? '';
    }
    return result;
  }
}
