import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../domain/receipt.dart';

/// Formats integer minor units as `300.00` (no symbol).
String formatAmount(int minor) {
  final negative = minor < 0;
  final abs = minor.abs();
  final whole = abs ~/ 100;
  final cents = (abs % 100).toString().padLeft(2, '0');
  return '${negative ? '-' : ''}$whole.$cents';
}

/// Minimal hand-rolled ESC/POS command builder (pure Dart, no plugins).
class EscPosBuilder {
  /// Characters per line, typically 32 for 58 mm / 42 for 80 mm paper.
  final int width;

  final BytesBuilder _bytes = BytesBuilder();

  EscPosBuilder({this.width = 32}) : assert(width > 0);

  static const List<int> initSequence = <int>[0x1B, 0x40];
  static const List<int> cutSequence = <int>[0x1D, 0x56, 0x42, 0x00];

  void init() => _bytes.add(initSequence);

  /// 0 = left, 1 = center, 2 = right.
  void align(int mode) {
    _bytes.addByte(0x1B);
    _bytes.addByte(0x61);
    _bytes.addByte(mode);
  }

  void bold(bool on) {
    _bytes.addByte(0x1B);
    _bytes.addByte(0x45);
    _bytes.addByte(on ? 1 : 0);
  }

  void inverse(bool on) {
    // GS B is the standard ESC/POS white-on-black mode supported by the
    // XP-365B receipt profile and most compatible thermal printers.
    _bytes.add(<int>[0x1D, 0x42, on ? 1 : 0]);
  }

  void scale({int width = 1, int height = 1}) {
    final w = width.clamp(1, 8) - 1;
    final h = height.clamp(1, 8) - 1;
    _bytes.add(<int>[0x1D, 0x21, (w << 4) | h]);
  }

  void rasterImage(img.Image source, {required int maxWidth}) {
    final resized = source.width > maxWidth
        ? img.copyResize(source, width: maxWidth)
        : source;
    final byteWidth = (resized.width + 7) ~/ 8;
    final data = Uint8List(byteWidth * resized.height);
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        if (img.getLuminance(resized.getPixel(x, y)) < 160) {
          data[y * byteWidth + (x ~/ 8)] |= 0x80 >> (x % 8);
        }
      }
    }
    _bytes.add(<int>[
      0x1D,
      0x76,
      0x30,
      0x00,
      byteWidth & 0xFF,
      (byteWidth >> 8) & 0xFF,
      resized.height & 0xFF,
      (resized.height >> 8) & 0xFF
    ]);
    _bytes.add(data);
    _bytes.addByte(0x0A);
  }

  /// Writes one padded line: [left] text with [right] right-aligned.
  void line(String left, String right) {
    final rightPart =
        right.length > width ? right.substring(right.length - width) : right;
    final leftSpace = width - rightPart.length;
    final leftPart = left.length > leftSpace
        ? left.substring(0, leftSpace < 0 ? 0 : leftSpace)
        : left.padRight(leftSpace);
    text('$leftPart$rightPart');
  }

  /// Writes a full-width centered or left text line (no newline included
  /// beyond the one added here).
  void text(String value) {
    for (final paragraph in value.split('\n')) {
      final runes = paragraph.runes.toList();
      if (runes.isEmpty) {
        _bytes.addByte(0x0A);
        continue;
      }
      for (var offset = 0; offset < runes.length; offset += width) {
        final end =
            offset + width < runes.length ? offset + width : runes.length;
        _bytes
            .add(utf8.encode(String.fromCharCodes(runes.sublist(offset, end))));
        _bytes.addByte(0x0A);
      }
    }
  }

  void feed(int lines) {
    _bytes.addByte(0x1B);
    _bytes.addByte(0x64);
    _bytes.addByte(lines);
  }

  void cut() => _bytes.add(cutSequence);

  List<int> build() {
    feed(4);
    cut();
    return _bytes.toBytes();
  }
}

/// Renders a [Receipt] as ESC/POS byte commands.
List<int> buildEscPosReceipt(Receipt receipt, {int width = 32}) {
  final builder = EscPosBuilder(width: width)..init();
  final symbol = receipt.currencySymbol;

  builder.align(1);
  builder.bold(true);
  builder.scale(width: 2, height: 2);
  builder.text(receipt.storeName);
  builder.scale();
  builder.bold(false);
  if (receipt.branchName.trim().isNotEmpty) {
    builder.text(receipt.branchName.trim());
  }
  if (receipt.storeAddress.trim().isNotEmpty) {
    builder.text(receipt.storeAddress.trim());
  }
  if (receipt.storePhone.trim().isNotEmpty) {
    builder.text(receipt.storePhone.trim());
  }
  if (receipt.hotline.trim().isNotEmpty) {
    builder.text('Hotline: ${receipt.hotline.trim()}');
  }
  builder.align(0);
  builder.align(1);
  builder.bold(true);
  builder.text('TAX INVOICE');
  builder.bold(false);
  builder.align(0);
  builder.text('-' * width);
  builder.align(1);
  builder.text('Invoice: ${receipt.invoiceNumber}');
  builder.text('Date: ${receipt.formattedDate}');
  if (receipt.formattedTime.isNotEmpty) {
    builder.text('Time: ${receipt.formattedTime}');
  }
  if (receipt.cashierName != null && receipt.cashierName!.trim().isNotEmpty) {
    builder.text('Cashier: ${receipt.cashierName!.trim()}');
  }
  if (receipt.terminalNumber.trim().isNotEmpty) {
    builder.text('Terminal: ${receipt.terminalNumber.trim()}');
  }
  if (receipt.customerName != null && receipt.customerName!.trim().isNotEmpty) {
    builder.text('Customer: ${receipt.customerName!.trim()}');
  }
  builder.align(0);
  builder.text('-' * width);
  builder.bold(true);
  builder.text('# Product       Price  Qty  Amount');
  builder.bold(false);
  for (var index = 0; index < receipt.lines.length; index++) {
    final item = receipt.lines[index];
    builder.text('${index + 1}. ${item.quantityText} x ${item.productName}');
    if (item.barcode != null) builder.text(item.barcode!);
    builder.line(
      'Price $symbol ${formatAmount(item.unitPriceMinor)} Qty ${item.quantityText}',
      '$symbol ${formatAmount(item.lineTotalMinor)}',
    );
  }
  builder.text('-' * width);
  builder.line('Subtotal', '$symbol ${formatAmount(receipt.subtotalMinor)}');
  if (receipt.discountMinor > 0) {
    builder.line('Discount', '-$symbol ${formatAmount(receipt.discountMinor)}');
  }
  if (receipt.taxMinor > 0) {
    builder.line('Tax', '$symbol ${formatAmount(receipt.taxMinor)}');
  }
  builder.inverse(true);
  builder.bold(true);
  builder.line('TOTAL', '$symbol ${formatAmount(receipt.totalMinor)}');
  builder.bold(false);
  builder.inverse(false);
  builder.line(
      'Cash received', '$symbol ${formatAmount(receipt.amountPaidMinor)}');
  builder.line('Balance', '$symbol ${formatAmount(receipt.amountDueMinor)}');
  builder.text('Products: ${receipt.lines.length}');
  builder.text(
      'Total qty: ${receipt.lines.fold<double>(0, (sum, line) => sum + line.quantity)}');
  if (receipt.changeMinor > 0) {
    builder.line('Change', '$symbol ${formatAmount(receipt.changeMinor)}');
  }
  builder.line('Method', receipt.paymentMethod.toUpperCase());
  if (receipt.footer.trim().isNotEmpty) {
    builder.align(1);
    builder.text(receipt.footer.trim());
    builder.align(0);
  }
  return builder.build();
}

Future<List<int>> buildEscPosReceiptWithLogo(
  Receipt receipt, {
  int width = 32,
}) async {
  final path = receipt.logoPath;
  if (path == null || path.isEmpty)
    return buildEscPosReceipt(receipt, width: width);
  try {
    final file = File(path);
    if (!await file.exists()) return buildEscPosReceipt(receipt, width: width);
    final image = img.decodeImage(await file.readAsBytes());
    if (image == null) return buildEscPosReceipt(receipt, width: width);
    final logo = EscPosBuilder(width: width)..init();
    logo.align(1);
    logo.rasterImage(image, maxWidth: width == 42 ? 576 : 384);
    logo.align(0);
    final body = buildEscPosReceipt(receipt, width: width);
    return <int>[
      ...logo._bytes.toBytes(),
      ...body.skip(EscPosBuilder.initSequence.length)
    ];
  } catch (_) {
    return buildEscPosReceipt(receipt, width: width);
  }
}
