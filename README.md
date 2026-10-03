# QubeXCore POS

Offline-first mobile retail point of sale built with Flutter and SQLite.

## Phase 1

A reliable local POS for a single store: products and categories, inventory
with stock movements, barcode scanning, cart and checkout with cash, card
recording, and customer credit, customer accounts and debt ledger, sales
history with filters, receipt generation with an ESC/POS printer abstraction,
local staff authentication, dashboard metrics, returns foundation, and
editable store settings. No cloud sync, no web admin, no backend — the app is
fully functional with no internet connection.

## Requirements

- Flutter 3.47.6 (stable), Dart 3.13.5
- An Android phone (Android 7+) for device runs, or an emulator
- No emulator, device, or network is needed for the test suite

```bash
export PATH="/home/ahmed_riyas/sdks/flutter/bin:$PATH"
```

## Setup and run

```bash
flutter pub get
flutter run
```

On first launch the app creates `qubexcore.db` locally, applies the full
migration set (schema v4), seeds settings defaults, and — in debug builds —
seeds demo data:

- Four categories: Beverages, Groceries, Snacks, Household
- Ten products with barcodes, prices, and stock (including a low-stock item
  so the dashboard shows it)
- Two customers with credit limits
- A development staff account

Seeding is idempotent (existing rows are skipped) and compiled behind
`kDebugMode`, so it never runs in release builds.

## Development login

| Username | PIN |
|---|---|
| `admin` | `1234` |

The account is forced to change its PIN on first login. PINs are stored only
as PBKDF2-HMAC-SHA256 hashes with a per-user salt and verified in constant
time.

## Tests

```bash
flutter pub get
dart format lib test
flutter analyze          # must report "No issues found!"
flutter test -j 1        # serial run; stable on this host
```

Widget and database tests use `sqflite_common_ffi` on the host; camera
scanning and printing are covered through fake/mock implementations. See
[docs/testing.md](docs/testing.md) for coverage details and
[docs/hardware.md](docs/hardware.md) for device options.

## Database behaviour

- Single local SQLite file (`qubexcore.db`); foreign keys enabled on every
  connection.
- Versioned migrations (v1–v4) recorded in `schema_migrations`; opening an
  older install applies every pending migration in one step. Migrations are
  never edited after release — changes ship as new numbered steps.
- All money is stored as integer minor units (one rupee = 100); no
  floating-point arithmetic touches financial values.
- Completing a sale is one transaction: sale, invoice number, sale items with
  product/price snapshots, stock decrement, stock movements, payment, and the
  customer credit ledger commit together or roll back together.
- Stock never changes without a matching stock movement; financial history is
  never hard-deleted (master data is archived instead).
- The currency symbol (`Rs` by default) comes from `app_settings` and is
  applied to every price, total, and receipt.

## Settings

The Settings screen edits store name/address/phone, currency symbol, invoice
prefix, tax rate (percent), negative-stock policy, receipt footer, and
printer options (enabled, name, paper width 32/42, auto-print). Validation
rejects empty required fields and out-of-range tax values before anything is
saved.

## Documentation

- [docs/architecture.md](docs/architecture.md) — layers, navigation, transactions
- [docs/database.md](docs/database.md) — schema, migrations, money strategy
- [docs/business-rules.md](docs/business-rules.md) — financial and inventory rules
- [docs/testing.md](docs/testing.md) — how to run and extend tests
- [docs/hardware.md](docs/hardware.md) — printers and scanners
- [docs/development-progress.md](docs/development-progress.md) — milestone status
