# QubeXCore POS — Testing

> How to run tests, what is covered, and what requires a physical device.
> Last updated: 2026-10-04

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
- **Real async never completes under FakeAsync.** Sign-in performs a sqflite FFI
  read and a PBKDF2 derivation. Neither finishes if the test only calls
  `tester.pump()`. Put the tap *and* the polling wait inside
  `tester.runAsync`, then `pump` once to render the result:

  ```dart
  await tester.runAsync(() async {
    await tester.tap(finder, warnIfMissed: false);
    for (var i = 0; i < 300; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (until()) return;
    }
  });
  await tester.pump();
  ```

- Never pass `warnIfMissed: false` while diagnosing. A tap that silently misses
  looks identical to an async operation that never completes.
- Use `result.dataOrNull` and `result.failureOrNull?.code`, not `result.data`
  or `result.code`, when reading an `AppResult`.
- UUID validation uses `UuidValidation.isValidUUID(fromString: value)` from
  `package:uuid/validation.dart`, not `Uuid.isValid` / `Uuid.tryParse`.
- **Pushed routes with async loads starve `pumpAndSettle`.** The route's
  spinner keeps scheduling frames while the isolate-backed DB read needs real
  event-loop turns, so `pumpAndSettle` alone never settles. Interleave
  real-delay windows with pumps, and only call `pumpAndSettle` last:

  ```dart
  await tester.runAsync(() async {
    await tester.tap(button);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pump();                 // route starts pushing
  await tester.runAsync(() async =>
      Future<void>.delayed(const Duration(milliseconds: 400)));
  await tester.pump(const Duration(milliseconds: 500));
  // ...repeat until the destination is on screen...
  await tester.pumpAndSettle();
  ```

- Modal route futures (`showDialog`, `showModalBottomSheet`) settle their
  continuation only on a real event-loop turn after the exit animation: tap in
  `runAsync`, `pumpAndSettle` to finish the animation, then a second
  `runAsync` window to drain the continuation (see `confirmDialogAction` in
  `customer_screens_test.dart`).
- A test that ends with the shell or dashboard mounted must drain the
  dashboard's chained reads (two `runAsync` delay + `pump` rounds), otherwise
  the framework reports a pending timer or a post-test
  `DatabaseException(database_closed)`.
- `MaterialApp` in tests needs `onGenerateRoute: AppRouter.onGenerateRoute`
  for any test that pushes a route, or navigation hits `_onUnknownRoute`.

## Current coverage

Baseline: **207 passing tests** across 33 files (see the table below). The
auth-gate widget tests take about 60 seconds on this host because each
sign-in performs a real 120000 iteration PBKDF2 derivation; this is expected,
not a hang.

| Suite | Covers |
|---|---|
| `test/core/database/app_database_test.dart` | Schema version 4, table existence, foreign keys enabled, settings seeded, migration ledger, persistence across reopen, pre-v3 install upgraded to v4 on open |
| `test/core/database/migration_v3_v4_test.dart` | v2→v4 migration data survival (`payments` rebuild, `products.description`, indexes, `foreign_key_check`) |
| `test/core/theme/app_theme_test.dart` | Brand primary colour, theme builds |
| `test/core/utils/id_generator_test.dart` | UUID uniqueness and validation |
| `test/core/utils/money_text_test.dart` | `Rs` default formatting, explicit symbol override, parsing, runtime symbol configuration, `MoneyText` rendering |
| `test/app/navigation_test.dart` | Shell loads with providers, tab navigation, async sales loading |
| `test/app/auth_gate_test.dart` | Gate blocks the register while signed out, wrong PIN error, forced PIN change, direct shell access |
| `test/features/checkout/checkout_service_test.dart` | Atomic sale completion, stock decrement, movements, cash change, underpayment block, insufficient stock, empty cart, invalid quantity, untracked products, card reference, credit ledger and limits, invoice sequencing, historical snapshots, rollback, idempotency, discount snapshot, sale reload |
| `test/features/checkout/checkout_auto_print_test.dart` | Printer failure after commit keeps the sale, clears the cart, and surfaces the failure message |
| `test/features/pos/cart_controller_test.dart` | Line totals in minor units, product snapshotting, cart totals, merge, increment/decrement, clear |
| `test/features/pos/pos_screens_test.dart` | New sale product filtering, stock caps, cart stepper, discount/note, checkout entry, `Rs` limit line |
| `test/features/barcode/scan_screen_test.dart` | Fake-scanner scan-to-cart, debounce, manual entry, permission-denied card |
| `test/features/products/product_repository_test.dart` | Product creation, barcode lookup, archive, validation failures |
| `test/features/products/development_seed_data_test.dart` | Debug catalog/customer seeding and idempotency |
| `test/features/settings/settings_repository_test.dart` | Defaults seeded, get/set, fallback, legacy tax key migration |
| `test/features/settings/settings_screen_test.dart` | Required-field and tax-range validation, settings persistence, toggles |
| `test/core/security/pin_hasher_test.dart` | Hash format, salt uniqueness, verify, malformed input, known PBKDF2 vector |
| `test/features/staff/staff_repository_test.dart` | `verifyPin`, credential-disclosure resistance, archived/deactivated, `setPin`, `changePin`, PIN format, update, archive, last-admin guard |
| `test/features/staff/staff_session_test.dart` | Sign in/out state, role accessors, `mustChangePin`, PIN rotation, detached repository |
| `test/features/receipts/receipt_builder_test.dart` | `Receipt.fromSale` mapping, `EscPosBuilder` byte-level output, printer-service success/failure, auto-print flag |
| `test/features/receipts/receipt_screen_test.dart` | Receipt rendering, print success/failure messaging, reprint |
| `test/features/dashboard/dashboard_repository_test.dart` | Today's sales, transaction count, outstanding credit, low-stock metrics |
| `test/features/sales/return_service_test.dart` | Atomic return, stock restore, quantity guard, rollback, credit `return_credit` ledger |
| `test/features/sales/sale_filters_test.dart` | Date-range, payment-method, customer filters |
| `test/ui/width_safety_test.dart` | No overflow on login, shell tabs, new sale, cart, checkout, settings at 360/390/430 px with long names |
| *(remaining suites)* | Categories CRUD, customers UI/ledger/repayments, inventory adjustments, stock guards, sales UI, staff UI, settings repository |

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
- [x] Customer repayment and overpayment rejection *(M7)*
- [x] Invoice number generation and uniqueness
- [x] Barcode product lookup
- [x] Historical price snapshots survive product edits
- [x] Balance-to-ledger invariant *(M7)*
- [x] Stock adjustment sign handling *(M4)*
- [x] Returns quantity guard and stock restore *(M10)*

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

- [x] PIN hashing and login verification *(M2)*
- [x] Forced PIN change *(M2)*
- [x] Sale staff attribution *(M2)*
- [x] Dashboard metrics *(M10)*
- [x] Sales history filters *(M10)*
- [x] Receipt model and ESC/POS builder *(M9)*
- [x] Sale succeeds when the printer throws *(M9)*
- [x] Barcode scan to cart flow using a fake scanner *(M8)*
- [x] Settings validation and persistence *(M11)*
- [x] Debug seed data idempotency *(M11)*
- [x] Existing v1 install upgrades to schema v4 *(M11)*
- [x] Width safety at 360/390/430 px for all primary screens *(M12)*

## Hardware-dependent checks

Camera scanning and Bluetooth thermal printing cannot be verified in automated
tests or on CI. Both are behind interfaces with fakes so the surrounding logic is
tested without devices. Device options and their status are listed in
[hardware.md](hardware.md). The following require a physical Android phone:

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
