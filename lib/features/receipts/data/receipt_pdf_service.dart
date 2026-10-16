import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../domain/receipt.dart';
import 'escpos_builder.dart';

/// Creates a readable PDF receipt with the configured business logo.
class ReceiptPdfService {
  Future<File> save(Receipt receipt) async {
    final directory = await getApplicationDocumentsDirectory();
    final name =
        receipt.invoiceNumber.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final file =
        File('${directory.path}${Platform.pathSeparator}receipt_$name.pdf');
    await file.writeAsBytes(build(receipt), flush: true);
    return file;
  }

  List<int> build(Receipt receipt) {
    img.Image? logo;
    final path = receipt.logoPath;
    if (path != null && path.isNotEmpty) {
      try {
        final file = File(path);
        if (file.existsSync()) logo = img.decodeImage(file.readAsBytesSync());
      } catch (_) {
        logo = null;
      }
    }

    final content = StringBuffer();
    var y = 800;
    if (logo != null) {
      const imageWidth = 150;
      const imageHeightLimit = 130;
      final imageHeight = (imageWidth * logo.height / logo.width)
          .round()
          .clamp(1, imageHeightLimit);
      final imageX = (420 - imageWidth) ~/ 2;
      final imageY = y - imageHeight;
      content.writeln(
          'q $imageWidth 0 0 $imageHeight $imageX $imageY cm /Im1 Do Q');
      y = imageY - 20;
    }
    void text(String value, {int size = 12, bool bold = false, int gap = 18}) {
      content.writeln(
          'BT /${bold ? 'F2' : 'F1'} $size Tf 48 $y Td (${_escape(value)}) Tj ET');
      y -= gap;
    }

    text(receipt.storeName, size: 20, bold: true, gap: 26);
    if (receipt.branchName.trim().isNotEmpty)
      text(receipt.branchName.trim());
    if (receipt.storeAddress.trim().isNotEmpty)
      text(receipt.storeAddress.trim());
    if (receipt.storePhone.trim().isNotEmpty) text(receipt.storePhone.trim());
    if (receipt.hotline.trim().isNotEmpty)
      text('Hotline: ${receipt.hotline.trim()}');
    y -= 8;
    text('TAX INVOICE', size: 14, bold: true, gap: 22);
    text('Invoice: ${receipt.invoiceNumber}');
    text('Date: ${receipt.formattedDate}');
    if (receipt.formattedTime.isNotEmpty) text('Time: ${receipt.formattedTime}');
    if (receipt.cashierName?.trim().isNotEmpty == true)
      text('Cashier: ${receipt.cashierName!.trim()}');
    if (receipt.terminalNumber.trim().isNotEmpty)
      text('Terminal: ${receipt.terminalNumber.trim()}');
    if (receipt.customerName?.trim().isNotEmpty == true)
      text('Customer: ${receipt.customerName!.trim()}');
    y -= 8;
    for (final line in receipt.lines) {
      text('${line.quantityText} x ${line.productName}', size: 13, gap: 17);
      text(
          '  ${receipt.currencySymbol} ${formatAmount(line.unitPriceMinor)}    ${receipt.currencySymbol} ${formatAmount(line.lineTotalMinor)}',
          size: 12,
          gap: 17);
    }
    y -= 8;
    text(
        'Subtotal: ${receipt.currencySymbol} ${formatAmount(receipt.subtotalMinor)}');
    if (receipt.discountMinor > 0)
      text(
          'Discount: -${receipt.currencySymbol} ${formatAmount(receipt.discountMinor)}');
    if (receipt.taxMinor > 0)
      text('Tax: ${receipt.currencySymbol} ${formatAmount(receipt.taxMinor)}');
    text('TOTAL: ${receipt.currencySymbol} ${formatAmount(receipt.totalMinor)}',
        size: 12, bold: true);
    text('Cash received: ${receipt.currencySymbol} ${formatAmount(receipt.amountPaidMinor)}');
    text('Balance: ${receipt.currencySymbol} ${formatAmount(receipt.amountDueMinor)}');
    if (receipt.changeMinor > 0)
      text(
          'Change: ${receipt.currencySymbol} ${formatAmount(receipt.changeMinor)}');
    if (receipt.amountDueMinor > 0)
      text(
          'Due: ${receipt.currencySymbol} ${formatAmount(receipt.amountDueMinor)}');
    text('Method: ${receipt.paymentMethod.toUpperCase()}');
    if (receipt.footer.trim().isNotEmpty) {
      y -= 8;
      text(receipt.footer.trim(), size: 13);
    }

    final stream = content.toString();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 420 842] /Resources << /Font << /F1 5 0 R /F2 6 0 R >>${logo == null ? '' : ' /XObject << /Im1 7 0 R >>'} >> /Contents 4 0 R >>',
      '<< /Length ${utf8.encode(stream).length} >>\nstream\n$stream\nendstream',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
    ];
    if (logo != null) {
      final jpg = img.encodeJpg(logo, quality: 85);
      objects.add(
          '<< /Type /XObject /Subtype /Image /Width ${logo.width} /Height ${logo.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length ${jpg.length} >>\nstream\n${latin1.decode(jpg)}\nendstream');
    }
    final output = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(latin1.encode(output.toString()).length);
      output.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }
    final xref = latin1.encode(output.toString()).length;
    output.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      output.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    output.write(
        'trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF');
    return latin1.encode(output.toString());
  }

  String _escape(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll('(', r'\(')
      .replaceAll(')', r'\)')
      .replaceAll(RegExp(r'[\r\n]'), ' ');
}
