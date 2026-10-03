---
name: ui-review
description: Design or review QubeXCore POS mobile UI for brand consistency, cashier speed, touch usability, responsive phone layouts, accessibility, states, and reusable components.
compatibility: OpenCode project skill for QubeXCore POS UI/UX
---

# QubeXCore POS UI Review

## UX goal
Optimize for:
- speed
- clarity
- low error rate
- phone usability
- obvious primary actions
- readable financial values

Avoid decorative complexity that slows checkout.

## Brand
Core palette:
- #000000
- #F9F9F9
- #A7A7A7
- #646464
- #0066FF
- #0052CC
- #002699

Semantic:
- paid/success → green
- bill/warning → orange
- debt/return/error/destructive → red

Do not rely on color alone.

## Mobile-first
- comfortable touch targets
- strong total/payment hierarchy
- no horizontal overflow
- handle keyboard on payment/forms
- efficient long lists
- clear loading/empty/error states

## Navigation
Primary destinations:
- Dashboard
- Sales
- Products
- Customers
- More

New Sale should always be easy to reach.

## New Sale
Hierarchy:
1. search/scan
2. categories
3. product list/grid
4. persistent cart summary
5. checkout

## Checkout
Make total dominant.
Clearly separate subtotal, discount, tax, and total.
Payment methods: Cash, Card, Credit.
Prevent accidental double submission.

## Review checklist
- Is the primary action obvious?
- Can a cashier finish quickly?
- Are amounts readable?
- Are touch targets comfortable?
- Are validation and error states useful?
- Does it work on narrow phone widths?
- Are components reusable?
