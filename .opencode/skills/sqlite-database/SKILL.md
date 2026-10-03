---
name: sqlite-database
description: Design and implement QubeXCore POS SQLite schemas, migrations, repositories, queries, indexes, constraints, transactions, persistence, and database tests.
compatibility: OpenCode project skill for SQLite-backed Flutter POS
---

# SQLite Database

## Principles
The local DB is the operational source of truth for Phase 1.
Prioritize correctness, migrations, constraints, transactions, and traceability.

## Schema
Maintain an explicit schema version.
Do not tell normal users to delete the database after schema changes.
Use migrations.

## IDs
Use local numeric primary keys where useful and stable UUIDs for business records that may sync later.

## Foreign keys and constraints
Enable foreign keys.
Define delete/update behavior deliberately.
Use uniqueness for business UUIDs, invoice numbers, barcode/SKU when applicable.

## Money
Use the project-wide safe money representation consistently.

## Transactions
Use SQLite transactions for multi-write operations.
Checkout writes must not run as unrelated commands.

## Repositories
UI must access data through repositories/services.
No raw SQL in widgets.

## Indexes
Add indexes for real access patterns such as:
- barcode
- SKU
- sale date
- sale customer
- ledger customer/date
- stock movement product/date

## History
Prefer archive/active flags for master data.
Do not hard-delete financial history.

## Future sync readiness
Do not implement sync yet, but use stable UUIDs and timestamps so records can be synchronized later.
