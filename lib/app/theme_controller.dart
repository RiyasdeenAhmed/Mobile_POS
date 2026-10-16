import 'package:flutter/material.dart';

import '../core/database/settings_repository.dart';

/// Persists and exposes the app-wide [ThemeMode].
///
/// The default is [ThemeMode.system]: the app follows the device's light or
/// dark setting until the cashier picks an explicit mode in Settings.
class ThemeController extends ChangeNotifier {
  ThemeController(this._settings, {ThemeMode initial = ThemeMode.system})
      : _mode = initial;

  final SettingsRepository _settings;

  static const String settingsKey = 'theme_mode';

  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static ThemeMode parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Restores the persisted mode. Safe to fire and forget at startup.
  Future<void> load() async {
    try {
      final stored = await _settings.getString(settingsKey);
      final parsed = parse(stored);
      if (parsed != _mode) {
        _mode = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Keep the current mode if settings cannot be read.
    }
  }

  /// Applies [mode] immediately and persists it best-effort.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _settings.setString(settingsKey, encode(mode));
    } catch (_) {
      // The UI already switched; persistence is retried on the next change.
    }
  }
}
