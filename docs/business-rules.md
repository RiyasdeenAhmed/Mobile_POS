# QubeXCore POS — Business Rules

> Financial, inventory, and customer-account rules enforced by the app.
> Last updated: 2026-10-03

These rules are enforced in the `data/` layer and covered by tests. The rules
here are the source of truth; code comments are secondary.

## 1. Money

- All money is **integer minor units**. One rupee = 100 minor units. Currency is
  **LKR**, symbol `Rs`.
- Financial columns are suffixed `_minor` and typed `INTEGER`.
- No floating-point arithmetic is used for financial values. Fractional
  quantities are converted with `.round()` and immediately stored as integers.
- Never mix a major-unit value into a minor-unit field.
- Display formatting and input parsing live in `MoneyFormat`; repositories
  never format strings.

## 2. Atomic sale completion

Completing a sale is a single SQLite transaction. Either every step succeeds or
every step is rolled back.

Required steps, in order:

1. Validate the request (non-empty cart, valid quantities, supported payment
   method, amounts)
2. Re-read each product to confirm it is still active, unarchived, and has
   sufficient stock
3. Insert the `sales` row
4. Reserve the next unique invoice number
5. Insert `sale_items` with full product snapshots
6. Decrement stock and insert `stock_movements`
7. Insert the `payments` row
8. For credit: enforce the credit limit, update `customers.balance_minor`, and
   insert a `customer_ledger` entry
9. Commit

Forbidden outcomes, all prevented by the transaction:

- A sale saved while stock is unchanged
- Stock reduced while the sale is missing
- A credit balance changed while the credit sale is missing

## 3. Historical accuracy

Each `sale_items` row stores immutable snapshots:

- `product_uuid`, `product_name`, `product_sku`, `product_barcode`
- `quantity`
- `unit_price_minor`, `unit_cost_minor`
- `discount_minor`, `line_total_minor`

Editing, renaming, or repricing a product later must never change an existing
sale. This is covered by a regression test.

## 4. Inventory

- Stock changes only through an explicit stock movement.
- `movement_type` is one of: `opening_stock`, `sale`, `sale_return`,
  `purchase`, `adjustment_in`, `adjustment_out`, `damage`.
- Every movement records a signed `quantity_change` and the resulting
  `quantity_after`.
- Creating a product with opening stock writes an `opening_stock` movement in
  the same transaction as the product insert.
- A sale decrements stock only for `track_stock = 1` products. Non-tracked
  products (services) write no movement and leave stock untouched.
- Editing a product's details does **not** change stock. Stock changes only via
  an adjustment movement with a recorded reason.
- Manual adjustments require a note.
- Stock may not fall below zero unless `allow_negative_stock` is enabled in
  settings.

## 5. Payments

### Cash
- `cash_received_minor` must be **greater than or equal to** the sale total.
- Underpayment is rejected before any write occurs.
- `change_minor = received - total`.
- **Change is not revenue.** It is recorded for accuracy and is excluded from
  sales totals.

### Card
- The sale is recorded as a card payment.
- An optional `reference` (authorisation note) may be stored.
- No payment gateway is integrated. A card row records the intent and amount
  only.

### Credit
- A customer is **required**. Credit checkout without a customer is rejected.
- The customer must be active and not archived.
- The customer must have a credit facility: `credit_limit_minor > 0`.
- The resulting balance must not exceed `credit_limit_minor`.
- A `customer_ledger` entry (`entry_type = 'debt_sale'`, positive signed amount,
  `balance_after_minor`) is written **inside the same transaction** as the sale.
- `amount_paid_minor = 0` and `amount_due_minor = total` for credit sales.

### Split payments
Not supported in Phase 1. One payment method per sale.

## 6. Invoice numbers

- Format `{invoice_prefix}-{sequence}`, e.g. `INV-000001`. Default prefix is
  `INV`.
- The sequence is stored in `app_settings.invoice_sequence` and incremented
  inside the sale transaction, guaranteeing uniqueness even under concurrency.
- The `sales.invoice_number` column is `UNIQUE` as a second line of defence.
- The prefix is configurable in settings so a branch or device prefix can be
  introduced later without a schema redesign.

## 7. Customer debt ledger

- The ledger is the authoritative accounting history.
- `amount_minor` is **signed**: positive for `debt_sale`, negative for
  `repayment` and `return_credit`.
- `customers.balance_minor` must always equal the sum of the customer's signed
  ledger amounts. This invariant is asserted in tests.
- Ledger entries are never deleted, edited, or reordered to "fix" a balance. A
  correction is a new entry.
- Historical accuracy is preserved via `balance_after_minor` on each entry.

## 8. Customer repayment

- A repayment requires a positive amount and an existing customer.
- The outstanding balance must be sufficient; overpayment is rejected (unless an
  explicit overpayment policy is added later).
- A repayment writes a `customer_ledger` entry (`entry_type = 'repayment'`,
  negative signed amount) and decrements `customers.balance_minor` in one
  transaction.
- Repayments never modify or delete the original credit sale.

## 9. Returns and refunds

Foundation in Phase 1; full UI follows once the core POS is stable.

Rules the service enforces:

- A return must reference an existing completed sale.
- Returned quantity per sale item cannot exceed `quantity sold - quantity
  already returned` across all prior returns.
- Returns are recorded as `returns`/`return_items`, **not** as arbitrary
  negative sales.
- Accepted returns restore stock via a `sale_return` movement and, for credit
  sales, adjust the customer ledger (`entry_type = 'return_credit'`).
- Return creation is atomic: return row, items, stock movements, and any ledger
  adjustment commit together or roll back together.

## 10. Staff authentication

- Staff authenticate locally against `staff_users` with a username and PIN.
- PINs are stored only as a PBKDF2-HMAC-SHA256 hash with a per-user random
  salt. Plaintext PINs are never persisted.
- Verification uses a constant-time comparison.
- Roles are `admin` and `cashier`.
- The development seed account (`admin` / `1234`) is marked
  `must_change_pin` and must rotate its PIN on first login.
- The signed-in staff UUID is recorded on sales, payments, stock movements, and
  ledger entries for attribution.
- Only admins may perform stock adjustments and manage staff accounts.

## 11. Receipts and printing

- **Commit the sale first. Printing is a post-commit action.**
- If printing fails, the sale remains completed. The UI reports
  "Sale completed — printing failed" and offers a reprint.
- A printer failure must never cancel, roll back, or corrupt a completed sale.
- Reprinting a receipt is always available from the sale record.

## 12. Archival and deletion

- Master data (products, categories, customers, staff) uses `is_active` and
  `is_archived` flags. Deletion is a soft archive.
- Financial history (sales, sale items, payments, stock movements, ledger
  entries, returns) is never hard-deleted.
- Foreign keys use `RESTRICT` where history must block deletion, and `SET NULL`
  where a master record may be removed without corrupting a transaction.

## 13. Dashboard and reporting

- Dashboard figures (today's sales, transaction count, outstanding credit,
  low-stock count) are computed from SQLite queries in a repository. No value is
  hardcoded.
- Sales history filters (date range, payment method, customer) query the
  database, not an in-memory list.

## 14. Validation

Inputs are validated before persistence and rejected with clear messages:

- Product: name required; prices and stock not negative; barcode and SKU unique
  when supplied
- Customer: name required; credit limit not negative
- Cart/checkout: cart not empty; quantity greater than zero; line total not
  negative; cash sufficient; customer present for credit
- Stock adjustment: quantity non-zero and of the correct sign for its movement
  type; note required

## 15. Offline operation

- No network calls are made at any point in Phase 1.
- All data is local. The app must remain fully functional with no internet
  connection.
