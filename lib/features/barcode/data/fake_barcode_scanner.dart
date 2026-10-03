import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/barcode_scanner.dart';

/// In-memory scanner for tests and camera-less development. Feed codes with
/// [emit]; toggle permission with [setPermissionDenied].
class FakeBarcodeScanner extends ChangeNotifier implements BarcodeScanner {
  final StreamController<String> _codes = StreamController<String>.broadcast();
  bool _torch = false;
  bool _permissionDenied = false;

  @override
  bool get value => _torch;

  @override
  bool get permissionDenied => _permissionDenied;

  @override
  Stream<String> get codes => _codes.stream;

  void emit(String code) {
    _codes.add(code);
  }

  void setPermissionDenied(bool denied) {
    _permissionDenied = denied;
    notifyListeners();
  }

  @override
  Future<void> toggleTorch() async {
    _torch = !_torch;
    notifyListeners();
  }

  @override
  void dispose() {
    _codes.close();
    super.dispose();
  }
}
