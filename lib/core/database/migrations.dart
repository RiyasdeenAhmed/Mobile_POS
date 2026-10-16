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

const MigrationStep migrationV3 = MigrationStep(
  version: 3,
  name: 'returns_foundation',
  up: _migrateToV3,
);

const MigrationStep migrationV4 = MigrationStep(
  version: 4,
  name: 'product_and_payment_details',
  up: _migrateToV4,
);

const MigrationStep migrationV5 = MigrationStep(
  version: 5,
  name: 'customer_credit_enabled',
  up: _migrateToV5,
);

const List<MigrationStep> kMigrations = <MigrationStep>[
  migrationV1,
  migrationV2,
  migrationV3,
  migrationV4,
  migrationV5,
  migrationV6,
  migrationV7,
  migrationV8,
];

const migrationV8 = MigrationStep(
  version: 8,
  name: 'staff_pin_lengths_and_printer_settings',
  up: _migrateToV8,
);

Future<void> _migrateToV8(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE staff_users ADD COLUMN pin_length INTEGER NOT NULL DEFAULT 4',
  );
  await db.execute(
    "INSERT OR IGNORE INTO app_settings(key, value, updated_at) VALUES ('printer_address', '', datetime('now'))",
  );
  await db.execute(
    "INSERT OR IGNORE INTO app_settings(key, value, updated_at) VALUES ('business_logo_path', '', datetime('now'))",
  );
}

Future<void> _migrateToV5(DatabaseExecutor db) async {
  await db.execute(
    'ALTER TABLE customers ADD COLUMN credit_enabled INTEGER NOT NULL DEFAULT 0',
  );
  // Existing customers that had a credit limit were operating on credit, so
  // keep their facility active after the flag is introduced.
  await db.execute(
    'UPDATE customers SET credit_enabled = 1 WHERE credit_limit_minor > 0',
  );
}

Future<void> _migrateToV3(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE returns (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      sale_id INTEGER NOT NULL,
      sale_uuid TEXT NOT NULL,
      customer_id INTEGER,
      staff_uuid TEXT,
      status TEXT NOT NULL DEFAULT 'completed',
      refund_total_minor INTEGER NOT NULL,
      refund_method TEXT NOT NULL,
      reason TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE RESTRICT,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_returns_sale_id ON returns(sale_id)');
  await db
      .execute('CREATE INDEX idx_returns_created_at ON returns(created_at)');

  await db.execute('''
    CREATE TABLE return_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      return_id INTEGER NOT NULL,
      sale_item_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_uuid TEXT NOT NULL,
      product_name TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_refund_minor INTEGER NOT NULL,
      line_refund_minor INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      FOREIGN KEY (return_id) REFERENCES returns (id) ON DELETE CASCADE,
      FOREIGN KEY (sale_item_id) REFERENCES sale_items (id) ON DELETE RESTRICT,
      FOREIGN KEY (product_id) REFERENCES products (id) ON DELETE RESTRICT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_return_items_return_id ON return_items(return_id)',
  );
  await db.execute(
    'CREATE INDEX idx_return_items_sale_item_id ON return_items(sale_item_id)',
  );
  await db.execute(
    'CREATE INDEX idx_return_items_product_id ON return_items(product_id)',
  );
}

Future<void> _migrateToV4(DatabaseExecutor db) async {
  await db.execute('ALTER TABLE products ADD COLUMN description TEXT');

  // payments gains customer_id. SQLite's legacy table-rebuild pattern: create
  // the new shape, copy every existing row with customer_id NULL, drop the
  // old table, rename, and recreate its indexes — all inside this migration's
  // transaction.
  await db.execute('''
    CREATE TABLE payments_new (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      sale_id INTEGER NOT NULL,
      payment_method TEXT NOT NULL,
      amount_minor INTEGER NOT NULL,
      reference TEXT,
      received_minor INTEGER,
      change_minor INTEGER,
      customer_id INTEGER,
      paid_at TEXT NOT NULL,
      staff_uuid TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE,
      FOREIGN KEY (customer_id) REFERENCES customers (id) ON DELETE SET NULL
    )
  ''');
  await db.execute('''
    INSERT INTO payments_new (
      id, uuid, sale_id, payment_method, amount_minor, reference,
      received_minor, change_minor, paid_at, staff_uuid, created_at
    )
    SELECT
      id, uuid, sale_id, payment_method, amount_minor, reference,
      received_minor, change_minor, paid_at, staff_uuid, created_at
    FROM payments
  ''');
  await db.execute('DROP TABLE payments');
  await db.execute('ALTER TABLE payments_new RENAME TO payments');
  await db.execute('CREATE INDEX idx_payments_sale_id ON payments(sale_id)');
  await db.execute(
    'CREATE INDEX idx_payments_payment_method ON payments(payment_method)',
  );
  await db.execute('CREATE INDEX idx_payments_paid_at ON payments(paid_at)');
}

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
    {'key': 'printer_width', 'value': '42'},
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

const migrationV6 =
    MigrationStep(version: 6, name: 'auditable_expenses', up: _migrateToV6);
Future<void> _migrateToV6(DatabaseExecutor db) async {
  await db.execute("""CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT, uuid TEXT NOT NULL UNIQUE,
    amount_minor INTEGER NOT NULL CHECK(amount_minor > 0),
    category TEXT NOT NULL, expense_at TEXT NOT NULL, note TEXT NOT NULL DEFAULT '',
    staff_uuid TEXT, created_at TEXT NOT NULL, replaces_id INTEGER REFERENCES expenses(id),
    voided_at TEXT, voided_by TEXT, void_reason TEXT
  )""");
  await db.execute('CREATE INDEX idx_expenses_date ON expenses(expense_at)');
}

const migrationV7 = MigrationStep(
  version: 7,
  name: 'operations_security_foundation',
  up: _migrateToV7,
);

Future<void> _migrateToV7(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE audit_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      event_type TEXT NOT NULL,
      actor_staff_uuid TEXT,
      entity_type TEXT,
      entity_id TEXT,
      details TEXT NOT NULL DEFAULT '{}',
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_audit_events_created_at ON audit_events(created_at)',
  );
  await db.execute('''
    CREATE TABLE backup_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      path TEXT NOT NULL,
      checksum TEXT NOT NULL,
      schema_version INTEGER NOT NULL,
      app_version TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at TEXT NOT NULL,
      completed_at TEXT,
      error TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE stocktakes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uuid TEXT NOT NULL UNIQUE,
      status TEXT NOT NULL,
      note TEXT,
      staff_uuid TEXT,
      started_at TEXT NOT NULL,
      completed_at TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE stocktake_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      stocktake_uuid TEXT NOT NULL,
      product_id INTEGER NOT NULL,
      product_uuid TEXT NOT NULL,
      product_name TEXT NOT NULL,
      expected_quantity REAL NOT NULL,
      counted_quantity REAL NOT NULL,
      variance REAL NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
  await db.execute(
    "INSERT OR IGNORE INTO app_settings(key, value, updated_at) VALUES ('tap_to_pay_enabled', '0', datetime('now'))",
  );
  await db.execute(
    "INSERT OR IGNORE INTO app_settings(key, value, updated_at) VALUES ('session_timeout_minutes', '0', datetime('now'))",
  );
  await db.execute(
    "INSERT OR IGNORE INTO app_settings(key, value, updated_at) VALUES ('backup_retention', '5', datetime('now'))",
  );
}
