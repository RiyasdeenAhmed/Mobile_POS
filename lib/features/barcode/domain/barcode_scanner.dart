import 'package:flutter/foundation.dart';

/// Camera-backed barcode scanning behind an interface so screens and tests
/// never depend on a physical camera.
abstract class BarcodeScanner extends ValueListenable<bool> {
  /// Decoded barcode values as the camera recognises them.
  Stream<String> get codes;

  /// Whether camera permission has been denied.
  bool get permissionDenied;

  /// Toggles the torch (flashlight).
  Future<void> toggleTorch();

  void dispose();
}
