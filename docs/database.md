# QubeXCore POS — Database

> SQLite schema, migrations, and money strategy. Last updated: 2026-10-04

## Connection

| Property | Value |
|---|---|
| Engine | SQLite via `sqflite` (device), `sqflite_common_ffi` (tests) |
| File | `qubexcore.db` in the platform app-support directory |
| Foreign keys | Enabled on every connection (`PRAGMA foreign_keys = ON`) |
| Schema version | `4` (see `AppDatabase.schemaVersion`; `onUpgrade` applies pending migrations up to it) |
| Migration ledger | `schema_migrations(version, name, applied_at)` |

`getDatabasesPath()` comes from `sqflite`, not `path_provider`.

## Migrations

Migrations are versioned, ordered, and applied exactly once. `MigrationRunner`
records each applied version in `schema_migrations`; `applyPending` runs only
versions above the current schema version.

Rules:

- **Never edit an already-released migration.** Add a new numbered step.
- Migrations are additive wherever possible — add columns/tables, do not rename
  or drop, so existing installs upgrade without data loss.
- Each step runs inside a transaction.

| Version | Name | Contents |
|---|---|---|
| 1 | `foundation` | All core tables, indexes, and settings defaults |
| 2 | `auth_and_store_settings` | *(M2)* `staff_users.must_change_pin`; settings for LKR, invoice prefix, receipt footer, tax, negative stock, printer |
| 3 | `returns_foundation` | `returns`, `return_items` |
| 4 | `product_and_payment_details` | `products.description`, `payments.customer_id` (legacy rows NULL) |

## Money strategy

**All monetary values are stored and computed as integers in minor units.**

One rupee = 100 minor units. Columns are suffixed `_minor`
(`selling_price_minor`, `total_minor`, `balance_minor`, ...). Currency is
**LKR**, symbol `Rs`, two decimal places.

Why integers: floating-point decimal arithmetic accumulates binary rounding
error, and repeated additions of fractional values drift. Totals computed in
doubles are unreliable for financial records.

Rules:

- `int` in Dart, `INTEGER` in SQLite. No `REAL`/`double` for money.
- Arithmetic is integer only. The only permitted use of floating point is
  converting a fractional `quantity` into a line amount, which is immediately
  rounded: `(unitPriceMinor * quantity).round()`.
- Display formatting lives in `MoneyFormat.format`; input parsing in
  `MoneyFormat.parseMajorToMinor`. The display symbol defaults to `Rs` and is
  overridden from `app_settings.currency_symbol` at app bootstrap and after
  each settings save, so every screen and receipt follows the setting.
- Quantities (`stock_quantity`, `sale_items.quantity`) are `REAL` because
  weighed goods may be fractional. This is deliberate and does not compromise
  money accuracy.

## Tables

### `schema_migrations`
`version` (PK), `name`, `applied_at`

### `app_settings`
`key` (PK), `value`, `updated_at`

Key/value store for local configuration. Managed through
`SettingsRepository`, which seeds defaults if absent.

| Key | Default | Purpose |
|---|---|---|
| `store_name` | `QubeXCore Store` | Receipt header |
| `store_address` | *(empty)* | Store address line on receipts *(M11)* |
| `store_phone` | *(empty)* | Store contact on receipts *(M11)* |
| `currency_symbol` | `Rs` | Money display symbol; injected into `MoneyFormat.defaultSymbol` at bootstrap and after each settings save *(M11)* |
| `currency_code` | `LKR` | Currency code |
| `invoice_sequence` | `0` | Monotonic invoice counter |
| `invoice_prefix` | `INV` | Invoice number prefix *(M2, editable in M11)* |
| `receipt_footer` | `Thank you for your purchase` | Receipt footer *(M2, editable in M11)* |
| `tax_rate_bps` | `0` | Tax rate in basis points (1800 = 18%); renamed from `tax_rate_minor` by `ensureSeededDefaults()` *(M6, editable as percent in M11)* |
| `allow_negative_stock` | `0` | Whether stock may go below zero *(M2, editable in M11)* |
| `printer_enabled` | `0` | Use the configured printer service *(M9, editable in M11)* |
| `printer_name` | *(empty)* | Label for the paired printer *(M9, editable in M11)* |
| `printer_width` | `32` | Receipt columns: 32 = 58 mm, 42 = 80 mm *(M9, editable in M11)* |
| `auto_print_receipt` | `0` | Print automatically after each completed sale *(M9, editable in M11)* |
| `db_schema_note` | `QubeXCore POS local schema v1` | Informational |

### `staff_users`
`id`, `uuid` (UNIQUE), `username` (UNIQUE), `display_name`, `role`, `password_hash`, `must_change_pin`, `is_active`, `is_archived`, `created_at`, `updated_at`

`password_hash` stores a PBKDF2-HMAC-SHA256 digest; plaintext PINs are never
persisted. `role` is `admin` or `cashier`. `must_change_pin` forces the
development seed account to rotate its PIN on first login.

### `categories`
`id`, `uuid` (UNIQUE), `name`, `parent_id` (FK → `categories`, SET NULL), `sort_order`, `is_active`, `is_archived`, `created_at`, `updated_at`

### `products`
`id`, `uuid` (UNIQUE), `sku` (UNIQUE), `barcode` (UNIQUE), `name`, `category_id` (FK → `categories`, SET NULL), `cost_price_minor`, `selling_price_minor`, `currency`, `stock_quantity` REAL, `reorder_level` REAL, `track_stock`, `is_active`, `is_archived`, `description` *(migration v4)*, `created_at`, `updated_at`

`track_stock = 0` means the product is not inventory-controlled (e.g. services):
sales do not decrement stock and write no stock movement. `is_archived` is a
soft delete — products referenced by past sales are never hard-deleted.

Indexes: `barcode`, `sku`, `name`, `category_id`.

### `customers`
`id`, `uuid` (UNIQUE), `name`, `phone`, `email`, `address`, `credit_limit_minor`, `balance_minor`, `is_active`, `is_archived`, `created_at`, `updated_at`

`balance_minor` is the current outstanding debt and is maintained
transactionally by the checkout and repayment services. `customer_ledger` is the
authoritative audit history; the two must always agree.

Indexes: `name`, `phone`.

### `sales`
`id`, `uuid` (UNIQUE), `invoice_number` (UNIQUE), `sale_at`, `customer_id` (FK → `customers`, SET NULL), `staff_uuid`, `subtotal_minor`, `discount_minor`, `tax_minor`, `total_minor`, `amount_paid_minor`, `change_minor`, `amount_due_minor`, `status`, `payment_method`, `notes`, `created_at`, `updated_at`

`status` is `completed` (Phase 1). `payment_method` is `cash`, `card`, or
`credit`. `change_minor` is money returned to the customer and is **not**
revenue. `amount_due_minor` is the credit portion owed.

Indexes: `sale_at`, `customer_id`, `invoice_number`, `status`.

### `sale_items`
`id`, `uuid` (UNIQUE), `sale_id` (FK → `sales`, CASCADE), `product_id` (FK → `products`, RESTRICT), `product_uuid`, `product_name`, `product_sku`, `product_barcode`, `quantity` REAL, `unit_price_minor`, `unit_cost_minor`, `discount_minor`, `line_total_minor`, `currency`, `created_at`

The `product_*` and `unit_*_minor` columns are **immutable snapshots** taken at
sale time. `product_name`, `product_sku`, `product_barcode`, `unit_price_minor`,
and `unit_cost_minor` guarantee the sale remains correct after the product is
renamed or repriced.

Indexes: `sale_id`, `product_id`.

### `payments`
`id`, `uuid` (UNIQUE), `sale_id` (FK → `sales`, CASCADE), `payment_method`, `amount_minor`, `reference`, `received_minor`, `change_minor`, `paid_at`, `staff_uuid`, `customer_id` *(migration v4, nullable)*, `created_at`

`received_minor`/`change_minor` are populated for cash only. `reference` holds
an optional card authorisation note. Card rows record an intent to pay; there
is no payment gateway integration in Phase 1.

Indexes: `sale_id`, `payment_method`, `paid_at`.

### `stock_movements`
`id`, `uuid` (UNIQUE), `product_id` (FK → `products`, RESTRICT), `movement_type`, `quantity_change` REAL, `quantity_after` REAL, `reference_type`, `reference_id`, `note`, `staff_uuid`, `created_at`

`movement_type` is one of `opening_stock`, `sale`, `sale_return`, `purchase`,
`adjustment_in`, `adjustment_out`, `damage`. `quantity_change` is signed;
`quantity_after` is the resulting stock level. Stock is never changed silently —
every change writes a movement.

Indexes: `(product_id, created_at)`, `movement_type`, `(reference_type, reference_id)`.

### `customer_ledger`
`id`, `uuid` (UNIQUE), `customer_id` (FK → `customers`, RESTRICT), `entry_type`, `amount_minor`, `balance_after_minor`, `sale_uuid`, `sale_id` (FK → `sales`, SET NULL), `note`, `staff_uuid`, `created_at`

`entry_type` is `debt_sale` (positive, increases debt), `repayment` (negative,
decreases debt), `return_credit`, or `adjustment`. `amount_minor` is
**signed**. `balance_after_minor` records the resulting outstanding balance so
history stays auditable even if a later correction is appended. Entries are
never deleted or rewritten.

Indexes: `(customer_id, created_at)`, `sale_uuid`, `entry_type`.

### `returns`
`id`, `uuid` (UNIQUE), `sale_id` (FK → `sales`, RESTRICT), `sale_uuid`, `customer_id`, `staff_uuid`, `status`, `refund_total_minor`, `refund_method`, `reason`, `created_at`, `updated_at`

### `return_items`
`id`, `uuid` (UNIQUE), `return_id` (FK → `returns`, CASCADE), `sale_item_id` (FK → `sale_items`, RESTRICT), `product_id`, `product_uuid`, `product_name`, `quantity` REAL, `unit_refund_minor`, `line_refund_minor`, `created_at`

## Referential integrity

- Foreign keys are enabled per connection.
- Financial history uses `ON DELETE RESTRICT` (`sale_items` → `products`,
  `stock_movements` → `products`, `customer_ledger` → `customers`) so products
  or customers referenced by transactions cannot be destroyed.
- Deleting a sale cascades to its own child rows (`sale_items`, `payments`) only
  as a structural guarantee; the application never deletes completed sales.
- Master-data references (`products` → `categories`, `sales` → `customers`) use
  `SET NULL` so removing a category or customer cannot corrupt history.

## Backup and portability

Phase 1 has no automated backup or sync. The database is a single local file.
Copying the app's data directory is the only backup mechanism.
