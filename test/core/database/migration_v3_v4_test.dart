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
    // Bring the schema to v2, as an existing install would be.
    await MigrationRunner.applyPending(db, 2);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedV2Data() async {
    const now = '2026-01-05T10:00:00.000Z';
    final productId = await db.insert('products', {
      'uuid': 'prod-1',
      'name': 'Espresso',
      'cost_price_minor': 500,
      'selling_price_minor': 1200,
      'currency': 'LKR',
      'stock_quantity': 8.0,
      'reorder_level': 2.0,
      'track_stock': 1,
      'created_at': now,
      'updated_at': now,
    });
    final customerId = await db.insert('customers', {
      'uuid': 'cust-1',
      'name': 'Nimal',
      'credit_limit_minor': 50000,
      'balance_minor': 2400,
      'created_at': now,
      'updated_at': now,
    });
    final saleId = await db.insert('sales', {
      'uuid': 'sale-1',
      'invoice_number': 'INV-0001',
      'sale_at': now,
      'customer_id': customerId,
      'subtotal_minor': 2400,
      'total_minor': 2400,
      'amount_paid_minor': 2400,
      'payment_method': 'cash',
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('sale_items', {
      'uuid': 'item-1',
      'sale_id': saleId,
      'product_id': productId,
      'product_uuid': 'prod-1',
      'product_name': 'Espresso',
      'quantity': 2.0,
      'unit_price_minor': 1200,
      'line_total_minor': 2400,
      'created_at': now,
    });
    await db.insert('payments', {
      'uuid': 'pay-1',
      'sale_id': saleId,
      'payment_method': 'cash',
      'amount_minor': 2400,
      'paid_at': now,
      'created_at': now,
    });
  }

  Future<Set<String>> indexNames() async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    return rows.map((row) => row['name'] as String).toSet();
  }

  test('v2 to v4 keeps existing rows and adds the new schema objects',
      () async {
    await seedV2Data();
    expect(await MigrationRunner.appliedVersions(db), {1, 2});

    await MigrationRunner.applyPending(db, 4);

    expect(await MigrationRunner.appliedVersions(db), {1, 2, 3, 4});

    // Existing rows survive with their data.
    final sale = (await db.query('sales')).single;
    expect(sale['invoice_number'], 'INV-0001');
    expect(sale['total_minor'], 2400);
    final payment = (await db.query('payments')).single;
    expect(payment['uuid'], 'pay-1');
    expect(payment['amount_minor'], 2400);

    // payments.customer_id exists and is NULL for legacy rows.
    expect(payment.keys, contains('customer_id'));
    expect(payment['customer_id'], isNull);

    // products.description exists and is NULL for legacy rows.
    final product = (await db.query('products')).single;
    expect(product.keys, contains('description'));
    expect(product['description'], isNull);

    // Returns tables exist and are empty.
    expect(await db.query('returns'), isEmpty);
    expect(await db.query('return_items'), isEmpty);

    // New indexes are present.
    final indexes = await indexNames();
    expect(
      indexes,
      containsAll(<String>[
        'idx_returns_sale_id',
        'idx_returns_created_at',
        'idx_return_items_return_id',
        'idx_return_items_sale_item_id',
        'idx_return_items_product_id',
        'idx_payments_sale_id',
        'idx_payments_payment_method',
        'idx_payments_paid_at',
      ]),
    );

    // Referential integrity is intact after the rebuild.
    final fkErrors = await db.rawQuery('PRAGMA foreign_key_check');
    expect(fkErrors, isEmpty);
  });

  test('applyPending from v2 is idempotent once applied', () async {
    await seedV2Data();
    await MigrationRunner.applyPending(db, 4);
    await MigrationRunner.applyPending(db, 4);

    expect(await MigrationRunner.appliedVersions(db), {1, 2, 3, 4});
    expect(await db.query('payments'), hasLength(1));
    expect(await db.query('returns'), isEmpty);
  });
}
