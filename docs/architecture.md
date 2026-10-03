# QubeXCore POS — Architecture

> Phase 1: Offline Mobile POS MVP. Last updated: 2026-10-04

## Purpose

QubeXCore POS is a mobile-first, offline-first retail point-of-sale application
for Android phones. All business data persists in a local SQLite database. No
internet connection, backend server, or cloud service is required.

## Principles

1. **Offline first** — SQLite is the operational source of truth. Nothing depends
   on network availability.
2. **Transactional integrity** — Any operation touching money, stock, or customer
   balances runs inside a single database transaction and rolls back fully on
   failure.
3. **Historical accuracy** — Transaction rows snapshot the product name, SKU,
   barcode, unit price, and unit cost at the time of sale. Editing a product
   later must never alter a past sale.
4. **Stable identifiers** — Business records use UUIDs (`uuid` package) rather
   than auto-increment keys, so records remain identifiable if synchronisation is
   added later. Integer primary keys are still present for local join efficiency.
5. **No hard deletes for financial history** — Master data uses archive/active
   flags. Financial records are never deleted.
6. **Integer money** — All monetary values are stored and computed as integer
   minor units (see [database.md](database.md#money-strategy)).
7. **No raw SQL in widgets** — UI talks to repositories/services. Persistence
   lives in the `data/` layer.
8. **Honest UI** — Buttons that are not wired up are disabled and documented.
   Nothing silently does nothing.

## Layers

Each feature is split into three layers:

| Layer | Location | Responsibility |
|---|---|---|
| `presentation/` | `lib/features/<feature>/presentation/` | Widgets, screens, form state. No SQL, no business rules. |
| `domain/` | `lib/features/<feature>/domain/` | Pure Dart models, value objects, enums, and pure business logic. No database dependency. |
| `data/` | `lib/features/<feature>/data/` | Repositories and services. Owns all SQL, transactions, and persistence. |

Dependencies point inward: `presentation -> domain`, `data -> domain`.
The `presentation` layer never imports `sqflite`.

## Directory layout

```text
lib/
├── main.dart                  App entry point, DB bootstrap
├── app/
│   ├── app.dart               MaterialApp + provider wiring
│   ├── bootstrap_screen.dart  Splash / async DB warm-up
│   ├── main_shell.dart        Bottom navigation shell
│   ├── providers.dart         Dependency injection
│   └── routes.dart            Route names, AppRouter, AppNavigator
├── core/
│   ├── database/
│   │   ├── app_database.dart        DB open, schema version, FK pragma
│   │   ├── migrations.dart          Versioned migration steps
│   │   └── settings_repository.dart app_settings access
│   ├── security/                   PIN hashing (M2)
│   ├── theme/                      Brand colours, theme, money formatting
│   ├── utils/                      UUID, result type, time helpers
│   └── widgets/                    Shared widgets
└── features/
    ├── auth/           Staff login and auth gate
    ├── dashboard/      Real metrics + recent transactions
    ├── categories/     Product categories
    ├── products/       Product CRUD (+ debug catalog seeder)
    ├── inventory/      Stock levels and movements
    ├── pos/            New Sale, cart, camera scan-to-cart
    ├── checkout/       Payment capture + atomic sale completion
    ├── customers/      Customer accounts + debt ledger (+ debug seeder)
    ├── sales/          Sales history, filters, detail, returns service
    ├── payments/       Payment model and method constants
    ├── barcode/        BarcodeScanner interface, mobile + fake impls
    ├── receipts/       Receipt model, ESC/POS builder, printer service
    ├── settings/       Editable store/sales/receipt settings
    └── staff/          Staff accounts, roles, development seeder
```

## State management

`provider` with `ChangeNotifier` for reactive UI state and `ProxyProvider` for
repository injection. No Riverpod, Bloc, or Redux.

- `CartController` — in-memory cart for the active sale.
- `StaffSession` — currently authenticated staff member (M2).
- `BarcodeScanner` (M8) — `ValueListenable<bool>` interface implemented by
  `MobileBarcodeScanner` (camera) and `FakeBarcodeScanner` (tests); the scan
  screen and the new-sale screen both listen through the interface.
- `PrinterService` (M9) — receipt print transport; ships with `MockPrinter`,
  swap in an ESC/POS device implementation without touching the UI.
- Repositories and services (`DashboardRepository`, `ReturnService`,
  `ReceiptPrintService`, `SettingsRepository`, ...) are stateless wrappers
  around `AppDatabase`, injected by `Provider` and rebuilt by `ProxyProvider`
  when the database instance changes.
- The money display symbol is a process-wide setting:
  `MoneyFormat.defaultSymbol` is set from `currency_symbol` in `main()` and
  again after each settings save.

## Navigation

A custom `onGenerateRoute` router (`AppRoutes`, `AppNavigator`) over Flutter's
`Navigator`. Route arguments are passed via `RouteSettings.arguments`.

```
/login  /dashboard  /pos/new-sale  /pos/cart  /pos/scan  /checkout  /receipt
/sales  /sales/detail  /products  /products/form  /categories
/customers  /customers/account  /customers/form  /inventory  /more  /settings
```

Bottom navigation: Dashboard, Sales, Products, Customers, More. A persistent
"New Sale" action is available from the shell app bar and FAB; the Products
and Customers tabs own their own app bar and FAB (Add product / Add customer)
and the shell defers its chrome to avoid stacked actions.

Theme: the app renders light everywhere except Login and Splash, which wrap
themselves in `QubeXCoreTheme.dark()` with light status-bar icons. Page
transitions follow the platform (`PageTransitionsTheme`: Android zoom with
predictive back, iOS Cupertino with interactive back-swipe), and confirmation
dialogs use `showAdaptiveDialog`.

## Error handling

`AppResult<T>` (`core/utils/result.dart`) is the contract for data-layer calls:

```dart
sealed class AppResult<T>       // Success<T> | Failure<T>
```

`Failure` carries a user-safe `message` and a machine-readable `code`
(`validation`, `not_found`, `database`, `duplicate_barcode`, `duplicate_sku`,
`insufficient_stock`, `insufficient_cash`, `empty_cart`,
`credit_requires_customer`, `credit_limit_exceeded`, ...).

Validation and business-rule failures are returned, not thrown. Unexpected
exceptions are caught at the repository/service boundary and converted into
`Failure` with `describeDatabaseError`. Raw exceptions never reach the UI.

## Transaction boundaries

The critical boundary is sale completion
(`features/checkout/data/checkout_service.dart`), which performs in one
transaction:

1. Validate request (cart, quantities, payment method, amounts)
2. Re-read products to confirm availability and current stock
3. Insert `sales` row
4. Reserve the next invoice number (`app_settings.invoice_sequence`)
5. Insert `sale_items` with full product snapshots
6. Decrement stock and insert `stock_movements` (`movement_type = 'sale'`)
7. Insert the `payments` row
8. For credit: enforce credit limit, update `customers.balance_minor`, insert
   `customer_ledger`

Any failure throws inside the transaction, and sqflite rolls back the whole
operation.

The second atomic boundary is return creation
(`features/sales/data/return_service.dart`): validating returnable
quantities, inserting `returns`/`return_items`, restoring stock via
`sale_return` movements, and appending a `return_credit` ledger entry for
credit sales all commit or roll back together.

## Testing strategy

See [testing.md](testing.md). Database-backed tests use
`sqflite_common_ffi` against `inMemoryDatabasePath`. Hardware-dependent
subsystems (camera, Bluetooth printing) are behind interfaces with fakes so the
core logic is testable without devices.

## Related documents

- [database.md](database.md) — schema, migrations, money strategy
- [business-rules.md](business-rules.md) — financial and inventory rules
- [testing.md](testing.md) — how to run tests, hardware checklist
- [development-progress.md](development-progress.md) — milestone status
