import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

class AppDatabase {
  static const int schemaVersion = 2;
  static const String defaultDbFileName = 'qubexcore.db';

  final Database db;

  AppDatabase._(this.db);

  static Future<AppDatabase> open({
    String? path,
    String fileName = defaultDbFileName,
  }) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), fileName);
    final database = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return AppDatabase._(database);
  }

  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await MigrationRunner.applyAll(db);
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await MigrationRunner.applyPending(db, newVersion);
  }

  Future<bool> areForeignKeysEnabled() async {
    final rows = await db.rawQuery('PRAGMA foreign_keys');
    if (rows.isEmpty) return false;
    final value = rows.first.values.first;
    return value == 1 || value == '1' || value == true;
  }

  Future<void> close() => db.close();
}
