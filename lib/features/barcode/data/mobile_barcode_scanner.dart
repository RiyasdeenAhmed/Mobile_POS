import 'package:flutter/foundation.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/barcode_scanner.dart';

/// [BarcodeScanner] backed by `mobile_scanner`. Camera start/stop and app
/// lifecycle are owned by the [MobileScanner] preview widget.
class MobileBarcodeScanner extends ChangeNotifier implements BarcodeScanner {
  final MobileScannerController controller;

  MobileBarcodeScanner({MobileScannerController? controller})
      : controller = controller ?? MobileScannerController() {
    this.controller.addListener(notifyListeners);
  }

  @override
  bool get value => controller.value.torchState == TorchState.on;

  @override
  bool get permissionDenied =>
      controller.value.error?.errorCode ==
      MobileScannerErrorCode.permissionDenied;

  @override
  Stream<String> get codes => controller.barcodes.map((capture) {
        for (final barcode in capture.barcodes) {
          final raw = barcode.rawValue;
          if (raw != null && raw.isNotEmpty) return raw;
        }
        return '';
      }).where((code) => code.isNotEmpty);

  @override
  Future<void> toggleTorch() => controller.toggleTorch();

  @override
  void dispose() {
    controller.removeListener(notifyListeners);
    controller.dispose();
    super.dispose();
  }
}
