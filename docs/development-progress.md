# QubeXCore POS — Development Progress

> Phase 1: Offline Mobile POS MVP. Last updated: 2026-10-03

## Legend

- `[x]` Completed — implemented and verified
- `[~]` In progress — partially implemented
- `[ ]` Not started
- `[!]` Blocked — cannot proceed, reason given

Nothing is marked complete without implementation and test evidence.

## Environment

| Item | Value |
|---|---|
| Flutter | 3.47.6 (stable) |
| Dart | 3.13.5 |
| Database | SQLite via `sqflite` (device) / `sqflite_common_ffi` (tests) |
| State management | Provider |
| Routing | Custom `onGenerateRoute` router |
| Currency | LKR, symbol `Rs`, integer minor units |
| Schema version | 2 |
| Tests | 99 passing |
| Static analysis | Clean |
| Git | Initialised in M0, baseline commit `9b6affe` |

---

## Locked decisions

- [x] PIN hashing = PBKDF2-HMAC-SHA256 with per-user random salt, constant-time compare
- [x] Development admin = `admin` / `1234`, dev-only, `must_change_pin` enforced
- [x] Currency = LKR / `Rs` from the beginning
- [x] Ledger model = `entry_type` + signed `amount_minor` + `balance_after_minor`
- [x] State and routing = Provider + existing custom router (no Riverpod, no go_router)
- [x] Returns = schema + service foundation now, full UI after core POS is stable
- [x] Git = `git init` plus baseline commit

## Packages

- [x] Add `cryptography: ^2.9.0` (PBKDF2-HMAC-SHA256) — M2
- [x] Add `mobile_scanner: ^7.4.2` (barcode camera) — M8
- [x] Verify `flutter pub get` and `flutter analyze` after each addition

---

## M0 — Git baseline and documentation

- [x] `git init`
- [x] Create `docs/development-progress.md`
- [x] Create `docs/architecture.md`
- [x] Create `docs/database.md`
- [x] Create `docs/business-rules.md`
- [x] Create `docs/testing.md`
- [x] Baseline commit (`9b6affe`, 197 files)

## M1 — Project foundation, theme, navigation, SQLite

- [x] QubeXCore brand palette (`app_colors.dart`)
- [x] Material 3 light and dark theme
- [x] Integer minor-unit money formatting and parsing
- [x] Bottom navigation shell (Dashboard, Sales, Products, Customers, More)
- [x] Named route table with `AppNavigator` helpers
- [x] `AppDatabase` with foreign keys enabled and schema version 1
- [x] Migration runner with `schema_migrations` ledger
- [x] Schema v1: all core tables and indexes
- [x] Repository DI via `ProxyProvider`
- [x] Tests: database, theme, money, ids, navigation

## M2 — Local staff authentication

- [x] `PinHasher` (PBKDF2-HMAC-SHA256, 120000 iterations, random 16-byte salt, constant-time compare)
- [x] Injectable iteration count (`StaffRepository.pinIterations`, seeder and provider seams); production locked at 120000, tests inject 1000 via `test/support/test_pin_iterations.dart`; verification always honours the count stored in the hash
- [x] Self-describing hash format `v1$pbkdf2-hmac-sha256$iterations$salt$digest`
- [x] Known-vector test cross-checked against an independent PBKDF2 implementation
- [x] Malformed hash returns false without throwing, and skips the expensive derivation
- [x] Migration v2 `auth_and_store_settings`
  - [x] `staff_users.must_change_pin`
  - [x] Settings migrated USD to `LKR` / `Rs`
  - [x] Added `invoice_prefix`, `receipt_footer`, `tax_rate_minor`, `allow_negative_stock`, store address/phone, printer keys
  - [x] Existing `products` / `sale_items` USD rows migrated to LKR
- [x] Development seed: `admin` / `1234` with `must_change_pin = 1`, debug builds only
- [x] `StaffRepository.verifyPin` (identical message for unknown user and wrong PIN)
- [x] `StaffRepository.setPin` and `changePin` with 4 to 8 digit validation
- [x] `StaffRepository.update` and `setArchived`, plus `isLastActiveAdmin` guard
- [x] `StaffSession` provider (sign in, change PIN, sign out, role and uuid accessors)
- [x] Real login screen (demo bypass removed)
- [x] `ChangePinScreen` forced flow when `must_change_pin` is set
- [x] `AuthGate` wraps the shell, so the register is unreachable while signed out
- [x] Logout from the More screen
- [x] `staffUuid` recorded on sales, payments, stock movements, and credit ledger entries
- [x] Staff management screen (admin only) with add, role, PIN reset, and archive
- [x] Tests: 12 hasher, 25 repository, 12 session, 4 auth-gate, 3 checkout attribution

## M3 — Categories and product management UI

- [x] Category list with real data (add/edit dialog, parent picker, archived styling)
- [x] Category create/edit form
- [x] Category archive with dependency guard (`productCount` blocks archive while active products reference it; FK-safe `invalid_parent` error on stale parent)
- [x] Product edit mode (route argument `productUuid`, prefill, `repository.update`)
- [x] Product form: category picker, opening stock (create only; edit shows current stock read-only), reorder level, track stock switch
- [x] Product search bar (name/SKU/barcode), category filter, low-stock filter (low + out of stock)
- [x] Product archive action with confirmation
- [x] Stock status colours with text (in stock green, low orange, out red, not tracked grey)
- [x] Tests: category CRUD/duplicate/guard, product update keeps stock, search, form widget create/edit/validation

## M4 — Inventory and stock movements

- [x] Fix `adjustStock` sign defect: sign enforced per movement type (`adjustment_in`/`purchase`/`sale_return`/`opening_stock` positive, `adjustment_out`/`damage` negative); moved to `StockMovementRepository`
- [x] Manual adjustments (`adjustment_in`/`adjustment_out`/`damage`) require a non-empty note
- [x] `StockMovementRepository` (list by product, list recent with product join, `lowStockProducts`/`lowStockCount`)
- [x] Inventory screen with Low stock / All products tabs, status colours + text, reorder info
- [x] Stock movement history per product (inside the adjust screen)
- [x] Stock adjustment screen at `/inventory/adjust` (type, signed preview, required note, admin-only form, read-only for cashiers)
- [x] Honour `allow_negative_stock` setting (read inside the movement transaction)
- [x] Products screen menu gained "Adjust stock" (reloads on return)
- [x] Tests: adjustment in/out signs, wrong-sign rejection, note guard, negative guard + setting override, movement rows, staff uuid, low-stock query, recent list join, adjust-screen widget tests

## M5 — POS and cart

- [x] `CartController` with integer minor-unit totals
- [x] `CartItem` snapshotting from product
- [x] New Sale screen with product search
- [x] Cart screen with quantity edit and remove
- [x] Persistent bottom cart summary
- [x] Category filter chips on New Sale (combined with search, reloads on return)
- [x] Walk-in customer support at checkout (always-visible customer card, walk-in choice in picker sheet, `CartController.note` passed as `CheckoutRequest.notes`)
- [x] Cart quantity blocked against available stock in the UI (`CartItem.availableStock` snapshot, add-to-cart capping with feedback snackbar, steppers capped/disabled at stock with "Maximum stock reached")
- [x] Line discounts (clamped to line gross) and order note in cart (dialog controller owned by screen state)
- [x] "View Cart" action in the New Sale bottom bar (`N items · Money · [View Cart]`)
- [x] Tests: cart caps/discounts/notes (16 unit) + New Sale / Cart / Checkout widget tests (3); suite at 145

## M6 — Checkout and sale transactions

- [x] Atomic `CheckoutService.completeSale` (single transaction)
- [x] Cash, card, and credit payment capture
- [x] Cash change calculation and underpayment rejection
- [x] Credit limit enforcement and customer ledger entry
- [x] Invoice numbering `INV-000001` (atomic sequence)
- [x] Stock decrement with `sale` movement
- [x] Product snapshot immutability in sale items
- [x] Idempotent submission via `saleUuid`
- [x] 15 regression tests for the above
- [x] Invoice prefix from settings (after M2 adds the key)
- [x] Tax applied from settings via `TaxCalculator` (basis points, half-up rounding, applied after discounts; `ensureSeededDefaults()` renames `tax_rate_minor` → `tax_rate_bps` and runs from `main()`)

## M7 — Customers and debt ledger

- [x] Customer repository and list screen
- [x] Credit checkout writes ledger and updates balance
- [x] Customer edit mode
- [x] Credit limit field in customer form
- [x] Customer archive action
- [x] `CustomerLedgerRepository`
- [x] `RepaymentService` (atomic ledger entry and balance update, overpayment guard)
- [x] Ledger table UI (date, type, reference, debit, credit, balance)
- [x] Ledger colours: debt red, payment green
- [x] Record repayment dialog (amount and method)
- [x] Tests: repayment math, overpayment rejected, ledger preserved, balance-to-ledger invariant (5 unit + 4 widget)

## M8 — Barcode scanning

- [x] `BarcodeScanner` interface, `mobile_scanner` implementation, and fake
- [x] Scan screen with camera preview
- [x] Scan to add-to-cart flow via `findByBarcode`
- [x] Debounce rapid repeated scans
- [x] Flashlight toggle
- [x] Camera permission handling with graceful denial
- [x] Android `CAMERA` permission, iOS `NSCameraUsageDescription`
- [x] "Product not found" message path
- [x] Tests: fake scanner add-to-cart, not found, debounce, permission denied, manual entry (5 widget)

## M9 — Receipts and thermal printing

- [x] Receipt preview screen loading real sale data
- [ ] `Receipt` model (shop, invoice, date, cashier, customer, items, totals, payment, received, change, footer)
- [ ] Settings-driven receipt preview (store name, currency, footer)
- [ ] `PrinterService` interface
- [ ] ESC/POS receipt builder
- [ ] Mock/no-op printer implementation (default)
- [ ] Post-commit print after checkout success
- [ ] Printer failure shows "Sale completed — printing failed" and permits reprint
- [ ] Reprint action on receipt and sale detail
- [ ] Printer configuration in settings
- [ ] Tests: builder output, sale succeeds when printer throws, reprint

## M10 — Dashboard, sales history, returns foundation

- [ ] `DashboardRepository` with real metrics (today sales, transaction count, credit outstanding, low stock)
- [ ] Dashboard metric cards and recent transactions from queries
- [ ] `SaleRepository` filters: date range, payment method, customer
- [ ] Sales screen filter UI
- [ ] Migration v3 `returns_foundation` (`returns`, `return_items`, indexes, foreign keys)
- [ ] Migration v4 `product_and_payment_details` (`payments.customer_id`, `products.description`, safe `payments` rebuild)
- [ ] `ReturnService` (atomic return, `sale_return` stock restore, ledger adjust, quantity guard)
- [ ] Tests: dashboard metrics, sales filters, return quantity guard, return rollback, stock restore

## M11 — Settings, seed data, cleanup, documentation

- [ ] Editable settings screen (shop name, address, phone, currency, invoice prefix, tax, negative stock, receipt footer, printer)
- [ ] LKR symbol wired into money display from settings
- [ ] Update money tests for the `Rs` symbol
- [ ] Development seed data (Beverages, Groceries, Snacks, Household; sample products with barcodes; sample customers) behind a dev-only guard
- [ ] Fill in `docs/hardware.md` (printer and scanner device matrix)
- [ ] Finalise `docs/architecture.md`, `docs/database.md`, `docs/business-rules.md`, `docs/testing.md`
- [ ] Update `README.md` (requirements, setup, run, test, development login, database behaviour)
- [ ] `flutter analyze` clean
- [ ] `flutter test` all passing

---

## Milestone gate

Every milestone must pass before proceeding:

- [ ] `dart format lib test`
- [ ] `flutter analyze` reports "No issues found!"
- [ ] `flutter test -j 1` all passing
- [ ] Report changed files, functionality, tests, limitations, suggested commit message
- [ ] Update this progress file

## Phase 1 definition of done

- [ ] Launch app, staff login
- [ ] Dashboard shows real metrics
- [ ] Create or select products
- [ ] Scan barcode or select a product
- [ ] Add to cart, modify quantity
- [ ] Select customer when required
- [ ] Checkout with cash, card, or credit
- [ ] Transaction saved locally and atomic
- [ ] Stock reduced and stock movement created
- [ ] Customer ledger entry created when required
- [ ] Receipt generated, print attempted, reprint available
- [ ] Completed sale visible in sales history
- [ ] Close app, reopen, all data intact
- [ ] `flutter analyze` clean
- [ ] `flutter test` all passing

## Known limitations

- **Cart is in-memory only** — an app restart mid-sale loses the active cart.
- **Hardware untested** — camera scanning and Bluetooth printing require a
  physical device; automated tests use fakes.
- **Default development PIN** — `admin` / `1234` is a documented offline-POS
  tradeoff, mitigated by forcing a PIN change on first login.
- **No backups or sync** — Phase 1 is local-only by design.
- **No returns UI yet** — returns ship as schema and service only.
- **Currency symbol not wired to settings** — `app_settings` seeds
  `currency_symbol = 'Rs'`, but the UI renders `$` via
  `MoneyFormat.defaultSymbol`; threading the setting through formatting is
  deferred to the settings/UI pass.
