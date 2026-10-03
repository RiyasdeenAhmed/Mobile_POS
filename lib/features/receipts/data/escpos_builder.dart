import 'dart:convert';
import 'dart:typed_data';

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
  /// Characters per line, typically 32 for 80 mm / 42 for 58 mm paper.
  final int width;

  final BytesBuilder _bytes = BytesBuilder();

  EscPosBuilder({this.width = 32});

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
    _bytes.add(utf8.encode(value));
    _bytes.addByte(0x0A);
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
  builder.text(receipt.storeName);
  builder.bold(false);
  if (receipt.storeAddress.trim().isNotEmpty) {
    builder.text(receipt.storeAddress.trim());
  }
  if (receipt.storePhone.trim().isNotEmpty) {
    builder.text(receipt.storePhone.trim());
  }
  builder.align(0);
  builder.text('-' * width);
  builder.text('Invoice: ${receipt.invoiceNumber}');
  builder.text('Date: ${receipt.saleAt}');
  if (receipt.cashierName != null && receipt.cashierName!.trim().isNotEmpty) {
    builder.text('Cashier: ${receipt.cashierName!.trim()}');
  }
  if (receipt.customerName != null && receipt.customerName!.trim().isNotEmpty) {
    builder.text('Customer: ${receipt.customerName!.trim()}');
  }
  builder.text('-' * width);
  for (final item in receipt.lines) {
    builder.text('${item.quantityText} x ${item.productName}');
    builder.line(
      '  @${formatAmount(item.unitPriceMinor)}',
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
  builder.bold(true);
  builder.line('TOTAL', '$symbol ${formatAmount(receipt.totalMinor)}');
  builder.bold(false);
  builder.line('Paid', '$symbol ${formatAmount(receipt.amountPaidMinor)}');
  if (receipt.changeMinor > 0) {
    builder.line('Change', '$symbol ${formatAmount(receipt.changeMinor)}');
  }
  if (receipt.amountDueMinor > 0) {
    builder.line('Due', '$symbol ${formatAmount(receipt.amountDueMinor)}');
  }
  builder.line('Method', receipt.paymentMethod.toUpperCase());
  if (receipt.footer.trim().isNotEmpty) {
    builder.align(1);
    builder.text(receipt.footer.trim());
    builder.align(0);
  }
  return builder.build();
}
