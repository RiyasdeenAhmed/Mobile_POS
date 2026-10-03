import 'package:sqflite/sqflite.dart';

class MigrationStep {
  final int version;
  final String name;
  final Future<void> Function(DatabaseExecutor db) up;

  const MigrationStep({
    required this.version,
    required this.name,
    required this.up,
  });
}

const MigrationStep migrationV1 = MigrationStep(
  version: 1,
  name: 'foundation',
  up: _migrateToV1,
);

const MigrationStep migrationV2 = MigrationStep(
  version: 2,
  name: 'auth_and_store_settings',
  up: _migrateToV2,
);

const List<MigrationStep> kMigrations = <MigrationStep>[
  migrationV1,
  migrationV2,
];

Future<void> _migrateToV2(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE staff_users ADD COLUMN must_change_pin INTEGER NOT NULL DEFAULT 0',
  );

  final now = DateTime.now().toUtc().toIso8601String();

  await db.update(
    'app_settings',
    {'value': 'LKR', 'updated_at': now},
    where: 'key = ?',
    whereArgs: ['currency_code'],
  );
  await db.update(
    'app_settings',
    {'value': 'Rs', 'updated_at': now},
    where: 'key = ?',
    whereArgs: ['currency_symbol'],
  );

  final settings = <Map<String, Object?>>[
    {'key': 'store_address', 'value': ''},
    {'key': 'store_phone', 'value': ''},
    {'key': 'invoice_prefix', 'value': 'INV'},
    {'key': 'receipt_footer', 'value': 'Thank you for your purchase'},
    {'key': 'tax_rate_minor', 'value': '0'},
    {'key': 'allow_negative_stock', 'value': '0'},
    {'key': 'printer_enabled', 'value': '0'},
    {'key': 'printer_name', 'value': ''},
    {'key': 'printer_width', 'value': '32'},
  ];
  for (final row in settings) {
    await db.insert(
      'app_settings',
      {'key': row['key'], 'value': row['value'], 'updated_at': now},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  await db.update(
    'products',
    {'currency': 'LKR'},
    where: 'currency = ?',
    whereArgs: ['USD'],
  );
  await db.update(
    'sale_items',
    {'currency': 'LKR'},
    where: 'currency = ?',
    whereArgs: ['USD'],
  );
}

Future<void> _migrateToV1(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE app_settings (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE staff_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      username TEXT NOT NULL UNIQUE,
      display_name TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'cashier',
      password_hash TEXT,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_staff_users_username ON staff_users(username)',
  );
  await db.execute(
    'CREATE INDEX idx_staff_users_is_active ON staff_users(is_active)',
  );

  await db.execute('''
    CREATE TABLE categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      parent_id INTEGER,
      sort_order INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (parent_id) REFERENCES categories (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_categories_name ON categories(name)');
  await db.execute(
    'CREATE INDEX idx_categories_parent_id ON categories(parent_id)',
  );

  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      sku TEXT UNIQUE,
      barcode TEXT UNIQUE,
      name TEXT NOT NULL,
      category_id INTEGER,
      cost_price_minor INTEGER NOT NULL DEFAULT 0,
      selling_price_minor INTEGER NOT NULL DEFAULT 0,
      currency TEXT NOT NULL DEFAULT 'USD',
      stock_quantity REAL NOT NULL DEFAULT 0,
      reorder_level REAL NOT NULL DEFAULT 0,
      track_stock INTEGER NOT NULL DEFAULT 1,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
  await db.execute('CREATE INDEX idx_products_sku ON products(sku)');
  await db.execute('CREATE INDEX idx_products_name ON products(name)');
  await db.execute(
    'CREATE INDEX idx_products_category_id ON products(category_id)',
  );

  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      phone TEXT,
      email TEXT,
      address TEXT,
      credit_limit_minor INTEGER NOT NULL DEFAULT 0,
      balance_minor INTEGER NOT NULL DEFAULT 0,
      is_active INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
  await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');

  await db.execute('''
    CREATE TABLE sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      invoice_number TEXT NOT NULL UNIQUE,
      sale_at TEXT NOT NULL,
      customer_id INTEGER,
      staff_uuid TEXT,
      subtotal_minor INTEGER NOT NULL DEFAULT 0,
      discount_minor INTEGER NOT NULL DEFAULT 0,
      tax_minor INTEGER NOT NULL DEFAULT 0,
      total_minor INTEGER NOT NULL DEFAULT 0,
      amount_paid_minor INTEGER NOT NULL DEFAULT 0,
      change_minor INTEGER NOT NULL DEFAULT 0,
      amount_due_minor INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'completed',
      payment_method TEXT NOT NULL DEFAULT 'cash',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_sales_sale_at ON sales(sale_at)');
  await db.execute('CREATE INDEX idx_sales_customer_id ON sales(customer_id)');
  await db.execute(
    'CREATE INDEX idx_sales_invoice_number ON sales(invoice_number)',
  );
  await db.execute('CREATE INDEX idx_sales_status ON sales(status)');

  await db.execute('''
    CREATE TABLE sale_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      sale_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_uuid TEXT NOT NULL,
      product_name TEXT NOT NULL,
      product_sku TEXT,
      product_barcode TEXT,
      quantity REAL NOT NULL,
      unit_price_minor INTEGER NOT NULL,
      unit_cost_minor INTEGER NOT NULL DEFAULT 0,
      discount_minor INTEGER NOT NULL DEFAULT 0,
      line_total_minor INTEGER NOT NULL,
      currency TEXT NOT NULL DEFAULT 'USD',
      created_at TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
    )
  ''');
  await db
      .execute('CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)');
  await db.execute(
    'CREATE INDEX idx_sale_items_product_id ON sale_items(product_id)',
  );

  await db.execute('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      sale_id INTEGER NOT NULL,
      payment_method TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      reference TEXT,
      received_minor INTEGER,
      change_minor INTEGER,
      paid_at TEXT NOT NULL,
      staff_uuid TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_payments_sale_id ON payments(sale_id)');
  await db.execute(
    'CREATE INDEX idx_payments_payment_method ON payments(payment_method)',
  );
  await db.execute('CREATE INDEX idx_payments_paid_at ON payments(paid_at)');

  await db.execute('''
    CREATE TABLE stock_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      product_id INTEGER NOT NULL,
      movement_type TEXT NOT NULL,
      quantity_change REAL NOT NULL,
      quantity_after REAL NOT NULL,
      reference_type TEXT,
      reference_id TEXT,
      note TEXT,
      staff_uuid TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_stock_movements_product_created ON stock_movements(product_id, created_at)',
  );
  await db.execute(
    'CREATE INDEX idx_stock_movements_movement_type ON stock_movements(movement_type)',
  );
  await db.execute(
    'CREATE INDEX idx_stock_movements_reference ON stock_movements(reference_type, reference_id)',
  );

  await db.execute('''
    CREATE TABLE customer_ledger (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      customer_id INTEGER NOT NULL,
      entry_type TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      balance_after_minor INTEGER NOT NULL,
      sale_uuid TEXT,
      sale_id INTEGER,
      note TEXT,
      staff_uuid TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE RESTRICT,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE SET NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_customer_ledger_customer_created ON customer_ledger(customer_id, created_at)',
  );
  await db.execute(
    'CREATE INDEX idx_customer_ledger_sale_uuid ON customer_ledger(sale_uuid)',
  );
  await db.execute(
    'CREATE INDEX idx_customer_ledger_entry_type ON customer_ledger(entry_type)',
  );

  final now = DateTime.now().toUtc().toIso8601String();
  final defaults = <Map<String, Object?>>[
    {'key': 'store_name', 'value': 'QubeXCore Store', 'updated_at': now},
    {'key': 'currency_symbol', 'value': r'$', 'updated_at': now},
    {'key': 'currency_code', 'value': 'USD', 'updated_at': now},
    {'key': 'invoice_sequence', 'value': '0', 'updated_at': now},
    {
      'key': 'db_schema_note',
      'value': 'QubeXCore POS local schema v1',
      'updated_at': now,
    },
  ];
  for (final row in defaults) {
    await db.insert(
      'app_settings',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

class MigrationRunner {
  static Future<void> applyAll(Database db) async {
    await ensureSchemaMigrationsTable(db);
    final applied = await appliedVersions(db);
    for (final step in kMigrations) {
      if (applied.contains(step.version)) continue;
      await applyStep(db, step);
    }
  }

  static Future<void> applyPending(Database db, int targetVersion) async {
    await ensureSchemaMigrationsTable(db);
    final applied = await appliedVersions(db);
    for (final step in kMigrations) {
      if (step.version > targetVersion) break;
      if (applied.contains(step.version)) continue;
      await applyStep(db, step);
    }
  }

  static Future<void> applyStep(Database db, MigrationStep step) async {
    await db.transaction((txn) async {
      await step.up(txn);
      await txn.insert(
        'schema_migrations',
        {
          'version': step.version,
          'name': step.name,
          'applied_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  static Future<void> ensureSchemaMigrationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        version INTEGER NOT NULL UNIQUE,
        name TEXT,
        applied_at TEXT NOT NULL
      )
    ''');
  }

  static Future<Set<int>> appliedVersions(Database db) async {
    final rows = await db.query(
      'schema_migrations',
      columns: ['version'],
    );
    return rows.map((row) => row['version'] as int).toSet();
  }
}
