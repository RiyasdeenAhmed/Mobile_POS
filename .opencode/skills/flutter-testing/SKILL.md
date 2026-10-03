---
name: flutter-testing
description: Verify QubeXCore POS with unit, widget, repository, and database tests; run formatter, flutter analyze, and flutter test before milestone completion.
compatibility: OpenCode project skill for Flutter testing
---

# Flutter Testing

## Baseline
Before major work:
- `flutter analyze`
- `flutter test`
- record pre-existing failures

## Required verification
After relevant changes:
1. format modified Dart files
2. run `flutter analyze`
3. run focused tests
4. run full `flutter test` before milestone completion

## High-priority tests
- cart calculations
- subtotal/discount/tax/total
- cash change
- insufficient payment
- stock reduction
- sale persistence
- sale rollback
- customer credit ledger
- customer repayment
- invoice numbering
- barcode lookup
- historical snapshots

## Checkout regression tests
Verify:
- empty cart blocked
- invalid quantity blocked
- insufficient stock blocked when configured
- cash underpayment blocked
- cash/card/credit recorded correctly
- credit requires customer
- rollback prevents partial state
- repeated taps do not create accidental duplicate transactions

## Hardware boundaries
Wrap camera/printer dependencies behind abstractions where practical.
Use mocks/fakes for automated tests.
Document physical-device checks separately.

## Completion report
State commands run, tests passed, skipped hardware checks, pre-existing failures, and remaining risks.
