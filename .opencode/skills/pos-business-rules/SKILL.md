---
name: pos-business-rules
description: Enforce QubeXCore POS sales, checkout, inventory, customer-credit, payment, receipt, return, invoice, and accounting rules.
compatibility: OpenCode project skill for QubeXCore POS
---

# POS Business Rules

## Money
Use one consistent money representation.
Prefer integer minor units where practical.
Never rely on careless floating-point logic for financial totals.

## Atomic sale completion
One database transaction should cover:
1. sale
2. sale items
3. payment
4. stock reduction
5. stock movements
6. customer ledger entry for credit
7. any transactionally maintained balance

Rollback everything if a critical step fails.

Never permit:
- sale saved but stock unchanged
- stock reduced but sale missing
- credit balance changed but credit sale missing

## Historical accuracy
Sale items should snapshot:
- product identifier
- product name
- quantity
- unit price
- cost price where needed
- discount
- line total

Editing products later must not change old transactions.

## Inventory
Inventory-changing events should create stock movements:
- opening_stock
- sale
- sale_return
- purchase
- adjustment_in
- adjustment_out
- damage

Do not silently change stock.

## Checkout
Cash:
- received amount must be >= total
- change is not revenue

Card:
- record payment method and optional reference
- do not imply real gateway integration unless implemented

Credit:
- customer required
- validate credit rules
- ledger entry must be part of the same transaction

## Customer ledger
Ledger entries must remain auditable.
Do not delete history to fix balances.

## Returns
Returns must reference the original completed sale.
Returned quantity cannot exceed sold quantity minus prior accepted returns.
Do not implement returns as arbitrary negative sales.

## Printing
Commit sale first.
Printing is a post-commit action.
Printer failure must keep the sale completed and allow reprint.

## Before completion
Review atomicity, duplicate prevention, stock correctness, money precision, historical snapshots, credit impact, retry/double-tap behavior, and tests.
