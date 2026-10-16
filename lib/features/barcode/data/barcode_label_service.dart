import 'dart:ui' as ui;
import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/database/app_database.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/utils/id_generator.dart';
import '../../products/domain/product.dart';

class BarcodeLabelService {
  BarcodeLabelService(this.database);
  final AppDatabase database;
  Future<String> ensureBarcode(String uuid) =>
      database.db.transaction((txn) async {
        final rows = await txn.query('products',
            where: 'uuid=? AND is_archived=0', whereArgs: [uuid]);
        if (rows.isEmpty) throw StateError('Product unavailable');
        final existing = rows.first['barcode'] as String?;
        if (existing != null && existing.isNotEmpty) return existing;
        String code;
        do {
          code =
              'QX${newBusinessId().replaceAll('-', '').substring(0, 12).toUpperCase()}';
        } while (
            (await txn.query('products', where: 'barcode=?', whereArgs: [code]))
                .isNotEmpty);
        await txn.update(
            'products',
            {
              'barcode': code,
              'updated_at': DateTime.now().toUtc().toIso8601String()
            },
            where: 'uuid=?',
            whereArgs: [uuid]);
        return code;
      });
  static void validate(String code, double width, double height, int copies) {
    if (!width.isFinite ||
        !height.isFinite ||
        width < 30 ||
        width > 150 ||
        height < 20 ||
        height > 150 ||
        copies < 1 ||
        copies > 100) {
      throw ArgumentError(
          'Use 30–150 mm width, 20–150 mm height, and 1–100 copies');
    }
    Barcode.code128().verify(code);
  }

  Future<List<int>> pdf(Product product,
      {required double width,
      required double height,
      required int copies,
      required bool price}) async {
    validate(product.barcode ?? '', width, height, copies);
    final font = pw.Font.ttf(await rootBundle.load('assets/fonts/Inter.ttf'));
    final doc =
        pw.Document(theme: pw.ThemeData.withFont(base: font, bold: font));
    final w = width * PdfPageFormat.mm, h = height * PdfPageFormat.mm;
    for (var i = 0; i < copies; i++) {
      doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(w, h, marginAll: 8),
          build: (_) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    pw.Text(product.name,
                        maxLines: 1, style: const pw.TextStyle(fontSize: 8)),
                    pw.SizedBox(height: 4),
                    pw.Expanded(
                        child: pw.BarcodeWidget(
                            barcode: Barcode.code128(),
                            data: product.barcode!,
                            drawText: false)),
                    pw.SizedBox(height: 3),
                    pw.Text(product.barcode!,
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(fontSize: 7)),
                    if (price)
                      pw.Text(MoneyFormat.format(product.sellingPriceMinor),
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 8)),
                  ])));
    }
    return doc.save();
  }

  Future<List<int>> png(Product product,
      {required double width,
      required double height,
      required bool price}) async {
    validate(product.barcode ?? '', width, height, 1);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width * 8, height * 8); // 203 dpi label printer raster.
    LabelPainter(product, price).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    try {
      return (await image.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

class LabelPainter extends CustomPainter {
  LabelPainter(this.product, this.price);
  final Product product;
  final bool price;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pad = size.width * .065;
    void text(String value, double y, double font) {
      final p = TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(
                  color: Colors.black, fontSize: font, fontFamily: 'Inter')),
          textDirection: TextDirection.ltr,
          maxLines: 1,
          ellipsis: '…')
        ..layout(maxWidth: size.width - 2 * pad);
      p.paint(canvas, Offset((size.width - p.width) / 2, y));
    }

    text(product.name, size.height * .06, size.height * .07);
    final code = product.barcode ?? '';
    try {
      final elements = Barcode.code128().make(code,
          width: size.width - 2 * pad,
          height: size.height * .45,
          drawText: false);
      for (final e in elements) {
        if (e is BarcodeBar && e.black) {
          canvas.drawRect(
              Rect.fromLTWH(
                  pad + e.left, size.height * .22 + e.top, e.width, e.height),
              Paint()
                ..color = Colors.black
                ..isAntiAlias = false);
        }
      }
      text(code, size.height * .70, size.height * .065);
      if (price) {
        text(MoneyFormat.format(product.sellingPriceMinor), size.height * .83,
            size.height * .075);
      }
    } catch (_) {
      text('Unsupported Code 128 value', size.height * .4, size.height * .06);
    }
  }

  @override
  bool shouldRepaint(covariant LabelPainter old) =>
      old.product != product || old.price != price;
}
