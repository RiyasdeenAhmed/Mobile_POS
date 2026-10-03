# QubeXCore POS — Hardware

> Printer and barcode-scanner device matrix for Phase 1.
> Last updated: 2026-10-04

Phase 1 runs entirely offline. Hardware support is provided through
interfaces (`PrinterService`, `BarcodeScanner`) with fake implementations in
tests, so the app is fully usable and testable without any device attached.

## Barcode scanning

| Option | Status | Notes |
|---|---|---|
| Built-in camera (`mobile_scanner` 7.4.2) | Supported in app | 1D/2D codes via on-device ML Kit; requires camera permission |
| Bluetooth HID scanner (keyboard-wedge) | Works via manual entry | Sends keystrokes; use **Manual entry** on the scan screen or type into any product search |
| USB/OTG scanner | Untested | Would also behave as keyboard input on Android |

Camera notes:

- Android permission: `android.permission.CAMERA` (declared in the manifest).
- iOS permission: `NSCameraUsageDescription`.
- The scan screen shows an inline permission prompt with a **Manual entry**
  fallback when the camera is denied.
- Scan results are debounced (1.5 s per code) so one physical scan adds
  exactly one cart line.
- The torch toggle uses `MobileScannerController.toggleTorch`.

Device-level verification (camera permission prompt, real printed barcode,
flashlight, rapid-scan debounce) requires a physical phone — see the hardware
checklist in [testing.md](testing.md#hardware-dependent-checks).

## Receipt printers

| Option | Status | Notes |
|---|---|---|
| Mock printer | Default | Captures jobs in memory; used by tests and development builds |
| ESC/POS Bluetooth printer (58 mm) | Format supported, device untested | e.g. Xprinter XP-58 / generic 58 mm SPP printers; set paper width **32** |
| ESC/POS Bluetooth printer (80 mm) | Format supported, device untested | e.g. Xprinter XP-80; set paper width **42** |
| ESC/POS USB printer | Untested | Same byte stream; depends on platform USB serial support |

Printing notes:

- Receipts are built as ESC/POS bytes by `EscPosBuilder` (init, alignment,
  bold, lines, feed, cut) from the shared `Receipt` model.
- The printer is **post-commit**: a print failure never cancels a completed
  sale. The UI shows *Sale completed — printing failed* and offers a reprint
  from the sale record.
- Auto-print after checkout is controlled by the `auto_print_receipt`
  setting on the Settings screen.
- Paper width (32/42 columns) is a Settings choice and affects line wrapping.
- Phase 1 ships `MockPrinter`; wiring a real transport (Bluetooth SPP/USB)
  means implementing a `PrinterService` subclass — no UI changes required.

## Recommended test device

Any Android phone with:

- Android 7.0+ (Flutter minimum for this app's target SDK)
- Camera with autofocus
- Bluetooth for thermal printers

All automated tests run on the host with `sqflite_common_ffi`, a fake
scanner, and a mock printer — no emulator or hardware is needed for
`flutter test`.
