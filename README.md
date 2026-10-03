# QubeXCore POS

Offline-first mobile retail point of sale built with Flutter and SQLite.

## Phase 1

Reliable local POS for a single store: products, inventory, sales, payments, customer credit, and receipts. No cloud sync, no web admin, no backend in Phase 1.

## Milestone 1

- Flutter app foundation and QubeXCore brand theme
- Navigation shell: Dashboard, Sales, Products, Customers, More
- New Sale always reachable from the shell
- Versioned SQLite schema (v1) with migrations, foreign keys, and seeded settings
- Repository layer for products, categories, customers, sales, and staff
- Runnable placeholder screens for later milestones
- Unit, repository, and widget tests

## Run tests

```bash
flutter pub get
flutter analyze
flutter test
```

Widget and database tests use `sqflite_common_ffi` on desktop and do not need an emulator or network.

## Architecture

```text
lib/
  app/          bootstrap, routes, shell, providers
  core/         theme, database, migrations, shared utils
  features/     data / domain / presentation per feature
```

- UI does not run raw SQL; repositories own persistence.
- Money is stored as integer minor units.
- Business records use stable UUIDs plus local numeric primary keys.
- Master data is archived, not hard-deleted; financial history is kept.
