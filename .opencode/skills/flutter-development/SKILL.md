---
name: flutter-development
description: Implement or refactor QubeXCore POS Flutter/Dart features, navigation, state management, architecture, widgets, forms, services, and app structure.
compatibility: OpenCode project skill for Flutter/Dart
---

# Flutter Development

## Objective
Build maintainable, mobile-first Flutter code for QubeXCore POS without over-engineering.

## Before editing
1. Read `pubspec.yaml`.
2. Inspect nearby feature conventions.
3. Reuse existing navigation/state/data-access patterns when sound.
4. Check whether a requested dependency already has an equivalent.

## Structure
Prefer feature-oriented code:

```text
lib/
  app/
  core/
  features/
    <feature>/
      data/
      domain/
      presentation/
```

Do not force layers where they add no value, but keep responsibilities clear.

## UI
- Keep widgets focused.
- Extract reusable components when duplication is meaningful.
- Keep business logic out of widgets.
- Keep raw database code out of presentation.
- Dispose controllers/resources correctly.
- Handle async lifecycle safely.
- Use const constructors where appropriate.

## State
Use the project's chosen state management consistently.
Separate transient UI state, cart/session state, and persisted business state.
Avoid global mutable state.

## Navigation
Important flows:
- login → dashboard
- dashboard → new sale
- new sale → cart
- cart → checkout
- checkout → receipt/result
- customers → customer account
- sales → sale detail

Do not discard an active cart silently.

## Dependencies
Before adding a package:
1. Check existing dependencies.
2. Prefer mature maintained packages.
3. Verify Flutter/Dart compatibility.
4. Keep dependencies minimal.
5. Explain why the package is required.

## Completion
Run formatting, `flutter analyze`, and relevant tests before completion.
