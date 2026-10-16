import 'package:flutter/services.dart';

import 'printer_service.dart';
import '../../../core/database/settings_repository.dart';

class BluetoothPrinterDevice {
  final String name;
  final String address;
  const BluetoothPrinterDevice({required this.name, required this.address});
}

class BluetoothPrinterStatus {
  final bool supported;
  final bool enabled;
  final bool permissionGranted;

  const BluetoothPrinterStatus({
    required this.supported,
    required this.enabled,
    required this.permissionGranted,
  });
}

enum PrinterProtocol { escPos, tspl }

extension PrinterProtocolLabel on PrinterProtocol {
  String get value => this == PrinterProtocol.tspl ? 'tspl' : 'esc_pos';
  String get label =>
      this == PrinterProtocol.tspl ? 'TSPL label mode' : 'ESC/POS receipt mode';
}

/// Test jobs for the XP-365B. Receipt printing requires the printer's
/// receipt mode, which speaks ESC/POS. TSPL is included only to identify a
/// printer that is still configured for label mode.
abstract final class Xprinter365bProfile {
  static List<int> escPosTest({int width = 32}) => <int>[
        0x1B,
        0x40,
        0x1B,
        0x61,
        0x01,
        ...'QubeXCore POS\n'.codeUnits,
        0x1B,
        0x61,
        0x00,
        ...'XP-365B ESC/POS test\n'.codeUnits,
        ...'Paper: ${width == 42 ? '80 mm' : '58 mm'}\n'.codeUnits,
        ...'Receipt mode ready\n\n\n'.codeUnits,
        0x1D,
        0x56,
        0x42,
        0x00,
      ];

  static List<int> tsplTest({int paperWidthMm = 58}) => <int>[
        ...'SIZE ${paperWidthMm == 80 ? 80 : 58} mm,40 mm\r\n'.codeUnits,
        ...'GAP 2 mm,0 mm\r\n'.codeUnits,
        ...'DIRECTION 1\r\n'.codeUnits,
        ...'CLS\r\n'.codeUnits,
        ...'TEXT 30,30,"3",0,1,1,"XP-365B TSPL test"\r\n'.codeUnits,
        ...'TEXT 30,90,"2",0,1,1,"Label mode detected"\r\n'.codeUnits,
        ...'PRINT 1,1\r\n'.codeUnits,
      ];

  /// Diagnostic job for field testing the actual XP-365B mode. It exercises
  /// the printable edges, alignment, reverse text, and native symbols without
  /// pretending that a Bluetooth write alone proves a readable receipt.
  static List<int> tsplDiagnostic({int paperWidthMm = 80}) {
    final width = paperWidthMm == 80 ? 80 : 58;
    final dots = width == 80 ? 608 : 432;
    return <int>[
      ...'SIZE $width mm,80 mm\r\n'.codeUnits,
      ...'GAP 0 mm,0 mm\r\n'.codeUnits,
      ...'DIRECTION 1\r\nREFERENCE 0,0\r\nCLS\r\n'.codeUnits,
      ...'BAR 16,16,$dots,2\r\n'.codeUnits,
      ...'TEXT 16,32,"2",0,1,1,"LEFT EDGE"\r\n'.codeUnits,
      ...'TEXT ${dots ~/ 2},70,"2",0,1,1,"CENTER"\r\n'.codeUnits,
      ...'TEXT 16,108,"2",0,1,1,"RIGHT EDGE $dots"\r\n'.codeUnits,
      ...'REVERSE 16,150,$dots,40\r\n'.codeUnits,
      ...'TEXT 24,158,"3",0,1,1,"XP-365B DIAGNOSTIC"\r\n'.codeUnits,
      ...'BARCODE 16,220,"128",60,1,0,2,2,"QUBEX123"\r\n'.codeUnits,
      ...'QRCODE ${width == 80 ? 420 : 250},220,L,5,A,0,"QUBEX-DIAGNOSTIC"\r\n'
          .codeUnits,
      ..._diagnosticBitmap(),
      ...'TEXT 16,310,"2",0,1,1,"CONTINUOUS MEDIA / 203 DPI"\r\n'.codeUnits,
      ...'PRINT 1,1\r\n'.codeUnits,
    ];
  }

  static List<int> _diagnosticBitmap() {
    final pixels = <int>[];
    for (var row = 0; row < 32; row++) {
      for (var byte = 0; byte < 4; byte++) {
        var value = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = byte * 8 + bit;
          if (row == 0 ||
              row == 31 ||
              x == 0 ||
              x == 31 ||
              x == row ||
              x == 31 - row) {
            value |= 1 << (7 - bit);
          }
        }
        pixels.add(value);
      }
    }
    return <int>[
      ...'BITMAP 16,370,4,32,0,'.codeUnits,
      ...pixels,
      0x0D,
      0x0A,
    ];
  }
}

/// Android Bluetooth Classic SPP transport for generic ESC/POS printers.
class AndroidBluetoothPrinter implements PrinterService {
  static const _channel = MethodChannel('qubexcore/bluetooth_printer');
  final String address;
  const AndroidBluetoothPrinter(this.address);

  static Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  static Future<void> openPairingSettings() =>
      _channel.invokeMethod<void>('openPairingSettings');

  static Future<BluetoothPrinterStatus> status() async {
    try {
      final row = await _channel.invokeMapMethod<String, dynamic>(
        'bluetoothStatus',
      );
      return BluetoothPrinterStatus(
        supported: true,
        enabled: row?['enabled'] == true,
        permissionGranted: row?['permissionGranted'] == true,
      );
    } on PlatformException catch (error) {
      if (error.code == 'unsupported') {
        return const BluetoothPrinterStatus(
          supported: false,
          enabled: false,
          permissionGranted: false,
        );
      }
      throw PrinterException(_messageFor(error));
    } on MissingPluginException {
      return const BluetoothPrinterStatus(
        supported: false,
        enabled: false,
        permissionGranted: false,
      );
    }
  }

  static Future<List<BluetoothPrinterDevice>> pairedDevices() async {
    try {
      if (!await requestPermission()) {
        throw const PrinterException('Nearby devices permission was denied');
      }
      final rows =
          await _channel.invokeListMethod<Map>('pairedDevices') ?? const [];
      return rows
          .map(
            (row) => BluetoothPrinterDevice(
              name: '${row['name']}',
              address: '${row['address']}',
            ),
          )
          .toList();
    } on PlatformException catch (error) {
      throw PrinterException(_messageFor(error));
    }
  }

  @override
  Future<void> print(List<int> job) async {
    try {
      if (!await requestPermission()) {
        throw const PrinterException('Nearby devices permission was denied');
      }
      await _channel
          .invokeMethod<void>('print', {'address': address, 'bytes': job});
    } on PlatformException catch (error) {
      throw PrinterException(_messageFor(error));
    }
  }

  Future<void> test(PrinterProtocol protocol, {int paperWidthMm = 58}) async {
    await print(protocol == PrinterProtocol.tspl
        ? Xprinter365bProfile.tsplTest(paperWidthMm: paperWidthMm)
        : Xprinter365bProfile.escPosTest(width: paperWidthMm == 80 ? 42 : 32));
  }

  Future<void> diagnostic({int paperWidthMm = 80}) async {
    await print(Xprinter365bProfile.tsplDiagnostic(paperWidthMm: paperWidthMm));
  }

  static String _messageFor(PlatformException error) => switch (error.code) {
        'permission_denied' => 'Nearby devices permission was denied',
        'disabled' => 'Bluetooth is turned off',
        'unsupported' => 'This device does not support Bluetooth',
        'print_failed' => error.message ?? 'Printer is offline or disconnected',
        _ => error.message ?? 'Bluetooth printing failed',
      };
}

class ConfiguredBluetoothPrinter implements PrinterService {
  final SettingsRepository settings;
  ConfiguredBluetoothPrinter(this.settings);
  @override
  Future<void> print(List<int> job) async {
    final enabled = await settings.getStringOrDefault('printer_enabled', '0');
    final address = await settings.getString('printer_address');
    if (enabled != '1' || address == null || address.isEmpty) {
      throw const PrinterException('No Bluetooth printer is configured');
    }
    await AndroidBluetoothPrinter(address).print(job);
  }
}
