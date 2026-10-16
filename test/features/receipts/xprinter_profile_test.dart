import 'package:flutter_test/flutter_test.dart';

import 'package:qubexcore_pos/features/receipts/data/android_bluetooth_printer.dart';

void main() {
  test('XP-365B ESC/POS test starts with reset and receipt text', () {
    final bytes = Xprinter365bProfile.escPosTest(width: 32);

    expect(bytes.take(2), orderedEquals([0x1B, 0x40]));
    expect(String.fromCharCodes(bytes), contains('XP-365B ESC/POS test'));
    expect(bytes, contains(0x1D));
  });

  test('XP-365B TSPL compatibility test uses label commands', () {
    final text = String.fromCharCodes(Xprinter365bProfile.tsplTest());

    expect(text, startsWith('SIZE 58 mm,40 mm\r\n'));
    expect(text, contains('PRINT 1,1'));
  });

  test('XP-365B diagnostic exercises printable markers and native symbols', () {
    final text = String.fromCharCodes(
      Xprinter365bProfile.tsplDiagnostic(paperWidthMm: 80),
    );

    expect(text, startsWith('SIZE 80 mm,80 mm\r\n'));
    expect(text, contains('GAP 0 mm,0 mm'));
    expect(text, contains('LEFT EDGE'));
    expect(text, contains('REVERSE'));
    expect(text, contains('BARCODE'));
    expect(text, contains('QRCODE'));
    expect(text, contains('BITMAP'));
    expect(text, contains('PRINT 1,1'));
  });
}
