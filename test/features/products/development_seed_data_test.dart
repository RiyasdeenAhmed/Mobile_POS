import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/features/customers/data/development_customer_seeder.dart';
import 'package:qubexcore_pos/features/products/data/development_catalog_seeder.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('seeds demo catalog and customers idempotently', () async {
    final db = await AppDatabase.open(path: inMemoryDatabasePath);
    addTearDown(db.close);

    await DevelopmentCatalogSeeder.seed(db);
    await DevelopmentCustomerSeeder.seed(db);

    Future<int> count(String table) async {
      final rows = await db.db.rawQuery('SELECT COUNT(*) AS c FROM $table');
      return rows.first['c'] as int;
    }

    expect(await count('categories'), 4);
    expect(await count('products'), 10);
    expect(await count('customers'), 2);

    final linked = await db.db.query(
      'products',
      where: 'category_id IS NULL',
      limit: 1,
    );
    expect(linked, isEmpty);

    final withBarcode = await db.db.query(
      'products',
      where: 'barcode IS NOT NULL',
      limit: 1,
    );
    expect(withBarcode, isNotEmpty);

    await DevelopmentCatalogSeeder.seed(db);
    await DevelopmentCustomerSeeder.seed(db);
    expect(await count('categories'), 4);
    expect(await count('products'), 10);
    expect(await count('customers'), 2);
  });
}
