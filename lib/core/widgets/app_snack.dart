import 'package:flutter/material.dart';

/// Central notification durations for every SnackBar in the app.
///
/// Normal success/info messages auto-dismiss quickly; errors stay longer so
/// they can be read. Critical validation errors should stay inline in the
/// form instead of relying on a transient SnackBar.
abstract final class AppSnackDurations {
  static const Duration info = Duration(milliseconds: 1800);
  static const Duration error = Duration(milliseconds: 3000);
}

enum AppSnackKind { info, error }

/// Shows a [SnackBar] with the centralized duration and error styling.
///
/// Replaces ad-hoc `ScaffoldMessenger.of(context).showSnackBar` calls so the
/// timing and look of notifications stay consistent across screens.
void showAppSnack(
  BuildContext context,
  String message, {
  AppSnackKind kind = AppSnackKind.info,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kind == AppSnackKind.error
          ? AppSnackDurations.error
          : AppSnackDurations.info,
      backgroundColor:
          kind == AppSnackKind.error ? const Color(0xFFC62828) : null,
    ),
  );
}

/// Hides the currently visible SnackBar, if any.
void hideCurrentAppSnack(BuildContext context) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
}
