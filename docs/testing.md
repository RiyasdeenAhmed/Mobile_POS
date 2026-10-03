# QubeXCore POS — Testing

> How to run tests, what is covered, and what requires a physical device.
> Last updated: 2026-10-03

## Requirements

- Flutter 3.47.6 (stable), Dart 3.13.5
- Linux SDK path used in this environment:
  `/home/ahmed_riyas/sdks/flutter/bin`

```bash
export PATH="/home/ahmed_riyas/sdks/flutter/bin:$PATH"
```

## Commands

```bash
flutter pub get          # resolve dependencies
dart format lib test     # format
flutter analyze          # static analysis, must report "No issues found!"
flutter test -j 1        # run all tests (serial for stability on this host)
```

Run a single suite:

```bash
flutter test test/features/checkout/checkout_service_test.dart -j 1
```

## Test infrastructure

- `sqflite_common_ffi` provides an in-process SQLite implementation for tests.
  Each repository/service test opens `AppDatabase.open(path: inMemoryDatabasePath)`,
  so every test starts from a freshly migrated, empty schema.
- `setUpAll` calls `sqfliteFfiInit()` and assigns `databaseFactory = databaseFactoryFfi`.
- Database-backed **widget** tests must wrap database open, `pumpWidget`, and
  `close` in `tester.runAsync(...)`. FakeAsync does not drive sqflite's real
  timers, which otherwise leaves pending timers and fails the test at the 10
  second timeout.
- Widget tests use a phone viewport: `tester.view.physicalSize = const Size(390, 844)`
  with `devicePixelRatio = 1.0`, and reset it via `addTearDown(tester.view.reset)`.
- Navigate by scoping to the navigation bar:
  `find.descendant(of: find.byType(NavigationBar), matching: find.text('Sales'))`.
- `DatabaseException` has no `.message`; use `describeDatabaseError(error, fallback)`
  from `core/utils/result.dart`.
- UUID validation uses `UuidValidation.isValidUUID(fromString: value)` from
  `package:uuid/validation.dart`, not `Uuid.isValid` / `Uuid.tryParse`.

## Current coverage

Baseline: **42 passing tests** across 9 files.

| Suite | Covers |
|---|---|
| `test/core/database/app_database_test.dart` | Schema version, table existence, foreign keys enabled, settings seeded, migration ledger, persistence across reopen |
| `test/core/theme/app_theme_test.dart` | Brand primary colour, theme builds |
| `test/core/utils/id_generator_test.dart` | UUID uniqueness and validation |
| `test/core/utils/money_text_test.dart` | Minor-unit formatting and parsing, `MoneyText` rendering |
| `test/app/navigation_test.dart` | Shell loads with providers, tab navigation, async sales loading |
| `test/features/checkout/checkout_service_test.dart` | Atomic sale completion, stock decrement, movements, cash change, underpayment block, insufficient stock, empty cart, invalid quantity, untracked products, card reference, credit ledger and limits, invoice sequencing, historical snapshots, rollback, idempotency, discount snapshot, sale reload |
| `test/features/pos/cart_controller_test.dart` | Line totals in minor units, product snapshotting, cart totals, merge, increment/decrement, clear |
| `test/features/products/product_repository_test.dart` | Product creation, barcode lookup, archive, validation failures |
| `test/features/settings/settings_repository_test.dart` | Defaults seeded, get/set, fallback |

## Required test coverage for Phase 1

Business logic:

- [x] Cart calculations
- [x] Sale totals, discount, tax
- [x] Cash change calculation
- [x] Insufficient cash rejected
- [x] Product creation and validation
- [x] Stock reduction on sale
- [x] Completed sale persistence
- [x] Sale rollback on mid-transaction failure
- [x] Customer credit ledger entry
- [ ] Customer repayment and overpayment rejection *(M7)*
- [x] Invoice number generation and uniqueness
- [x] Barcode product lookup
- [x] Historical price snapshots survive product edits
- [ ] Balance-to-ledger invariant *(M7)*
- [ ] Stock adjustment sign handling *(M4)*
- [ ] Returns quantity guard and stock restore *(M10)*

Checkout regression cases:

- [x] Empty cart blocked
- [x] Invalid quantity blocked
- [x] Insufficient stock blocked
- [x] Cash underpayment blocked
- [x] Cash, card, and credit recorded correctly
- [x] Credit requires a customer
- [x] Rollback prevents partial state
- [x] Repeated submission does not create duplicate transactions

Planned additions:

- [ ] PIN hashing and login verification *(M2)*
- [ ] Forced PIN change *(M2)*
- [ ] Sale staff attribution *(M2)*
- [ ] Dashboard metrics *(M10)*
- [ ] Sales history filters *(M10)*
- [ ] Receipt model and ESC/POS builder *(M9)*
- [ ] Sale succeeds when the printer throws *(M9)*
- [ ] Barcode scan to cart flow using a fake scanner *(M8)*

## Hardware-dependent checks

Camera scanning and Bluetooth thermal printing cannot be verified in automated
tests or on CI. Both are behind interfaces with fakes so the surrounding logic is
tested without devices. The following require a physical Android phone:

- [ ] Camera permission prompt appears and denial is handled gracefully
- [ ] Barcode is detected from a real printed barcode
- [ ] Flashlight toggle works
- [ ] Repeated rapid scans add one item, not many
- [ ] Thermal printer connects over Bluetooth
- [ ] ESC/POS receipt prints with correct alignment and cut
- [ ] Printer failure surfaces "Sale completed — printing failed" and permits reprint
- [ ] Reprint from a past sale works

See [architecture.md](architecture.md#testing-strategy) for the interface/fake
pattern and [development-progress.md](development-progress.md) for status.

## Conventions

- Test file layout mirrors `lib/`: `test/<path mirrors lib path>/<name>_test.dart`.
- Prefer repository and service tests over widget tests for business logic;
  widget tests are reserved for wiring and user-visible behaviour.
- Every milestone ends with `dart format`, `flutter analyze`, and `flutter test -j 1`
  all clean before proceeding.
- Pre-existing failures must be separated from newly introduced ones before
  reporting a milestone.
