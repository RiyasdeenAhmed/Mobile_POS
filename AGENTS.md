# QubeXCore POS — OpenCode Project Instructions

## Project goal
Build QubeXCore POS as a reliable mobile-first, offline-first retail POS application.

Phase 1 scope:
- Flutter + Dart
- SQLite
- Products and categories
- Inventory and stock movements
- Barcode scanning
- Cart and checkout
- Cash, card-recording, and customer-credit payments
- Customer accounts and debt ledger
- Sales history
- Receipt generation and printer abstraction
- Local staff authentication
- Tests and documentation

Do not introduce Laravel, PostgreSQL, cloud sync, Firebase, WebSockets, multi-branch cloud logic, or a web admin app until the offline POS MVP is stable.

## Before editing
1. Inspect the project tree.
2. Read `pubspec.yaml`.
3. Read existing architecture/docs.
4. Run `flutter pub get`.
5. Run `flutter analyze`.
6. Run `flutter test`.
7. Separate pre-existing failures from newly introduced ones.

## Skills
Use:
- `flutter-development`
- `pos-business-rules`
- `sqlite-database`
- `flutter-testing`
- `ui-review`

Always load `pos-business-rules` for checkout, inventory, customer credit, refunds, invoices, payments, or accounting work.

Always load `sqlite-database` for schema, migrations, repositories, persistence, or transaction work.

Before declaring a milestone complete, load `flutter-testing`.

## Architecture rules
Prefer feature-based organization:

```text
lib/
  app/
  core/
  features/
    auth/
    dashboard/
    categories/
    products/
    inventory/
    pos/
    checkout/
    customers/
    sales/
    payments/
    barcode/
    receipts/
    settings/
```

Keep UI, business logic, repositories, and persistence separated.
Do not put raw SQL in widgets.
Do not create giant all-purpose Dart files.

## Critical financial rules
- Completing a sale must be atomic.
- Sale, items, payment, stock movements, and customer ledger updates must succeed or fail together.
- Never save a sale without correct stock updates.
- Never change stock without the corresponding sale/adjustment record.
- Preserve historical product/price/cost snapshots in transaction rows.
- Do not hard-delete financial history.
- Printer failure must not cancel an already completed sale.
- Credit checkout requires a valid customer.
- Use safe money handling.
- Use stable UUIDs for business records where practical.

## Git rules
Do not push unless explicitly requested.
Do not rewrite Git history.
Do not delete unrelated user code.

After a stable milestone, report:
- files changed
- functionality implemented
- tests run
- known limitations
- suggested commit message

## Definition of done
A feature must:
- persist correctly
- validate inputs
- handle errors
- obey business rules
- pass relevant tests
- pass static analysis or document a pre-existing blocker

Always keep the app runnable.
