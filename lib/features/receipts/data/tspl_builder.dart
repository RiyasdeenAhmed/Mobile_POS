import 'dart:io';

import 'package:image/image.dart' as img;

import '../domain/receipt.dart';
import 'escpos_builder.dart';

/// Builds receipts for XP-365B printers operating in TSPL label mode.
/// The XP-365B is 203 DPI and advertises a maximum printable width of 76 mm,
/// even when 80 mm media is loaded. Keep a 2 mm margin on both sides.
List<int> buildTsplReceipt(
  Receipt receipt, {
  required int paperWidthMm,
  int? horizontalOffsetDots,
  int? contentWidthDots,
  int? logoWidthDots,
  int fontScale = 1,
}) {
  final widthMm = paperWidthMm == 80 ? 80 : 58;
  final canvasDots = widthMm == 80 ? 640 : 464;
  final printableDots = widthMm == 80 ? 608 : 432;
  final safeContentWidth = (contentWidthDots ?? printableDots)
      .clamp(240, printableDots)
      .toInt();
  final safeOffset = (horizontalOffsetDots ?? 0).clamp(
        -((printableDots - safeContentWidth) ~/ 2),
        ((printableDots - safeContentWidth) ~/ 2),
      ).toInt();
  final marginDots = ((canvasDots - safeContentWidth) ~/ 2) + safeOffset;
  final scale = fontScale.clamp(1, 2).toInt();
  final characters = widthMm == 80 ? 42 : 32;
  final lines = <String>[
    receipt.storeName,
    if (receipt.branchName.trim().isNotEmpty) receipt.branchName.trim(),
    if (receipt.storeAddress.trim().isNotEmpty) receipt.storeAddress.trim(),
    if (receipt.storePhone.trim().isNotEmpty) receipt.storePhone.trim(),
    if (receipt.hotline.trim().isNotEmpty) 'Hotline: ${receipt.hotline.trim()}',
    '',
    'TAX INVOICE',
    'Invoice: ${receipt.invoiceNumber}',
    'Date: ${receipt.formattedDate}',
    if (receipt.formattedTime.isNotEmpty) 'Time: ${receipt.formattedTime}',
    if (receipt.cashierName?.trim().isNotEmpty == true)
      'Cashier: ${receipt.cashierName!.trim()}',
    if (receipt.terminalNumber.trim().isNotEmpty)
      'Terminal: ${receipt.terminalNumber.trim()}',
    if (receipt.customerName?.trim().isNotEmpty == true)
      'Customer: ${receipt.customerName!.trim()}',
    '',
    '------------------------------------------',
    '# Item                    Price  Qty  Amount',
    ...receipt.lines.asMap().entries.expand((entry) {
      final line = entry.value;
      return <String>[
          '${entry.key + 1}. ${line.quantityText} x ${line.productName}',
          if (line.barcode?.trim().isNotEmpty == true) line.barcode!.trim(),
          _columns(
            'Price ${receipt.currencySymbol} ${formatAmount(line.unitPriceMinor)}  Qty ${line.quantityText}',
            '${receipt.currencySymbol} ${formatAmount(line.lineTotalMinor)}',
            characters,
          ),
        ];
    }),
    '',
    '------------------------------------------',
    _columns(
        'Subtotal',
        '${receipt.currencySymbol} ${formatAmount(receipt.subtotalMinor)}',
        characters),
    if (receipt.discountMinor > 0)
      _columns(
          'Discount',
          '-${receipt.currencySymbol} ${formatAmount(receipt.discountMinor)}',
          characters),
    if (receipt.taxMinor > 0)
      _columns(
          'Tax',
          '${receipt.currencySymbol} ${formatAmount(receipt.taxMinor)}',
          characters),
    _columns(
        'TOTAL',
        '${receipt.currencySymbol} ${formatAmount(receipt.totalMinor)}',
        characters),
    _columns(
        'Cash received',
        '${receipt.currencySymbol} ${formatAmount(receipt.amountPaidMinor)}',
        characters),
    _columns(
        'Balance',
        '${receipt.currencySymbol} ${formatAmount(receipt.amountDueMinor)}',
        characters),
    'Products: ${receipt.lines.length} · Total qty: ${receipt.lines.fold<double>(0, (sum, line) => sum + line.quantity)}',
    if (receipt.changeMinor > 0)
      _columns(
          'Change',
          '${receipt.currencySymbol} ${formatAmount(receipt.changeMinor)}',
          characters),
    _columns('Method', receipt.paymentMethod.toUpperCase(), characters),
    if (receipt.footer.trim().isNotEmpty) '',
    if (receipt.footer.trim().isNotEmpty) receipt.footer.trim(),
  ];

  final wrapped = <String>[];
  for (final line in lines) {
    if (line.isEmpty) {
      wrapped.add('');
      continue;
    }
    final runes = line.runes.toList();
    for (var offset = 0; offset < runes.length; offset += characters) {
      final end = (offset + characters).clamp(0, runes.length);
      wrapped.add(String.fromCharCodes(runes.sublist(offset, end)));
    }
  }

  final lineHeightDots = 30 * scale;
  final logo = _LogoCommand.fromReceipt(
    receipt,
    widthMm,
    logoWidthDots,
    contentWidthDots: safeContentWidth,
    marginDots: marginDots,
  );
  final heightDots = (wrapped.length + 3) * lineHeightDots + logo.heightDots;
  final heightMm = (heightDots / 8).ceil();
  final commands = StringBuffer()
    ..writeln('SIZE $widthMm mm,$heightMm mm')
    // Continuous receipt media has no label gap. A non-zero GAP is what
    // causes the large blank feeds seen on XP-365B receipt rolls.
    ..writeln('GAP 0 mm,0 mm')
    ..writeln('DIRECTION 1')
    ..writeln('REFERENCE 0,0')
    ..writeln('CLS');
  var y = lineHeightDots + logo.heightDots;
  final taxInvoiceIndex = wrapped.indexOf('TAX INVOICE');
  for (var index = 0; index < wrapped.length; index++) {
    final line = wrapped[index];
    if (line.isNotEmpty) {
      final isStore = index == 0;
      final isTotal = line.startsWith('TOTAL');
      final font = isStore || isTotal ? '3' : '2';
      final charWidth = (font == '3' ? 16 : 12) * scale;
      final maxChars = (safeContentWidth / charWidth).floor();
      final safe = _fit(line, maxChars);
      final centered =
          (taxInvoiceIndex >= 0 && index <= taxInvoiceIndex) ||
          line == 'TAX INVOICE' ||
          line.startsWith('Invoice:') ||
          line.startsWith('Date:') ||
          line.startsWith('Time:') ||
          line.startsWith('Cashier:') ||
          line.startsWith('Customer:') ||
          line.startsWith('Method') ||
          line.startsWith('Thank');
      final x = centered
          ? marginDots +
              ((safeContentWidth - safe.length * charWidth) ~/ 2)
                  .clamp(0, safeContentWidth)
          : marginDots;
      if (isTotal) {
        commands.writeln(
            'REVERSE $marginDots,$y,$safeContentWidth,${lineHeightDots + 4}');
      }
      commands.writeln(
        'TEXT $x,$y,"$font",0,$scale,$scale,"${_escape(safe)}"',
      );
    }
    y += lineHeightDots + (line.startsWith('TOTAL') ? 6 : 0);
  }
  final commandText = commands.toString();
  const marker = 'CLS\n';
  final markerIndex = commandText.indexOf(marker);
  final prefix = commandText.substring(0, markerIndex + marker.length);
  final body = commandText.substring(markerIndex + marker.length);
  return [
    ...prefix.codeUnits,
    ...logo.bytes,
    ...body.codeUnits,
    ...'PRINT 1,1\r\n'.codeUnits,
  ];
}

class _LogoCommand {
  final List<int> bytes;
  final int heightDots;

  const _LogoCommand(this.bytes, this.heightDots);

  static _LogoCommand fromReceipt(
    Receipt receipt,
    int widthMm,
    int? configuredWidth,
    {
    required int contentWidthDots,
    required int marginDots,
    }
  ) {
    final path = receipt.logoPath;
    if (path == null || path.isEmpty) return const _LogoCommand([], 0);
    try {
      final source = img.decodeImage(File(path).readAsBytesSync());
      if (source == null) return const _LogoCommand([], 0);
      final maxWidth = configuredWidth == null
          ? (widthMm == 80 ? 360 : 260)
          : configuredWidth.clamp(80, widthMm == 80 ? 480 : 340).toInt();
      final resized = img.copyResize(source, width: maxWidth);
      final bytesPerRow = (resized.width + 7) ~/ 8;
      final bitmap = <int>[];
      for (var y = 0; y < resized.height; y++) {
        for (var byte = 0; byte < bytesPerRow; byte++) {
          var value = 0;
          for (var bit = 0; bit < 8; bit++) {
            final x = byte * 8 + bit;
            if (x < resized.width && resized.getPixel(x, y).luminance < 150) {
              value |= 1 << (7 - bit);
            }
          }
          bitmap.add(value);
        }
      }
      final x = marginDots + ((contentWidthDots - resized.width) ~/ 2);
      final header = 'BITMAP $x,24,$bytesPerRow,${resized.height},0,';
      return _LogoCommand(
        [...header.codeUnits, ...bitmap, 0x0D, 0x0A],
        resized.height + 24,
      );
    } catch (_) {
      return const _LogoCommand([], 0);
    }
  }
}

String _fit(String value, int maxChars) {
  final runes = value.runes.toList();
  if (runes.length <= maxChars) return value;
  if (maxChars <= 1) return String.fromCharCodes(runes.take(maxChars));
  return '${String.fromCharCodes(runes.take(maxChars - 1))}…';
}

String _columns(String left, String right, int width) {
  final safeRight = _fit(right, width - 1);
  final leftWidth = width - safeRight.length - 1;
  final safeLeft = _fit(left, leftWidth);
  return '${safeLeft.padRight(leftWidth)} $safeRight';
}

String _escape(String value) => value
    .replaceAll('\\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll(RegExp(r'[\r\n]'), ' ');
