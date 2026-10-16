import '../../payments/domain/payment.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/theme/money_text.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';

/// Builds a printable A4 invoice from immutable sale data.
///
/// Pure and plugin-free: runs in unit tests without a device or bindings.
class InvoiceDocument {
  const InvoiceDocument({
    required this.sale,
    this.payments = const [],
    required this.items,
    required this.settings,
    this.customerName,
    this.cashierName,
  });

  final Sale sale;
  final List<Payment> payments;
  final List<SaleItem> items;
  final Map<String, String> settings;
  final String? customerName;
  final String? cashierName;

  static const PdfColor _brand = PdfColor(0, 0.4, 1);

  String _money(int minor) {
    final symbol = settings['currency_symbol'];
    return MoneyFormat.format(
      minor,
      symbol: (symbol == null || symbol.isEmpty) ? null : symbol,
    );
  }

  String get _storeName {
    final name = settings['store_name']?.trim() ?? '';
    return name.isEmpty ? 'QubeXCore Store' : name;
  }

  String get _when {
    final parsed = DateTime.tryParse(sale.saleAt);
    if (parsed == null) return sale.saleAt;
    return DateFormat('d MMM yyyy, HH:mm').format(parsed.toLocal());
  }

  String _itemName(SaleItem item) {
    final sku = item.productSku;
    if (sku == null || sku.isEmpty) return item.productName;
    return '${item.productName} ($sku)';
  }

  pw.Document build() {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _header(),
          pw.SizedBox(height: 20),
          _meta(),
          pw.SizedBox(height: 24),
          _itemsTable(),
          pw.SizedBox(height: 20),
          _totals(),
          pw.Spacer(),
          _footer(),
        ],
      ),
    );
    return doc;
  }

  pw.Widget _header() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _storeName,
                style: const pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (settings['store_address']?.isNotEmpty == true)
                pw.Text(
                  settings['store_address']!,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              if (settings['store_phone']?.isNotEmpty == true)
                pw.Text(
                  settings['store_phone']!,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
            ],
          ),
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'INVOICE',
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: _brand,
              ),
            ),
            pw.Text(
              sale.invoiceNumber,
              style: const pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(
              _when,
              style: const pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _meta() {
    final rows = <MapEntry<String, String>>[
      if (customerName?.isNotEmpty == true) MapEntry('Customer', customerName!),
      if (cashierName?.isNotEmpty == true) MapEntry('Cashier', cashierName!),
      MapEntry('Payment', sale.paymentMethod.toUpperCase()),
      MapEntry('Status', sale.status.toUpperCase()),
    ];
    return pw.Column(
      children: [
        for (final row in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 90,
                  child: pw.Text(
                    row.key,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
                pw.Text(
                  row.value,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _itemsTable() {
    return pw.TableHelper.fromTextArray(
      headers: ['#', 'Item', 'Qty', 'Unit price', 'Total'],
      data: [
        for (var i = 0; i < items.length; i++)
          [
            '${i + 1}',
            _itemName(items[i]),
            items[i].quantityText,
            _money(items[i].unitPriceMinor),
            _money(items[i].lineTotalMinor),
          ],
      ],
      headerStyle: const pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      headerAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FlexColumnWidth(0.5),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(0.7),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
    );
  }

  pw.Widget _totalRow(String label, int amountMinor, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(_money(amountMinor), style: style)
        ],
      ),
    );
  }

  pw.Widget _totals() {
    return pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(
        width: 250,
        child: pw.Column(
          children: [
            for (final payment in payments)
              _totalRow(PaymentMethods.labelOf(payment.paymentMethod),
                  payment.amountMinor),
            _totalRow('Subtotal', sale.subtotalMinor),
            if (sale.discountMinor != 0)
              _totalRow('Discount', sale.discountMinor),
            if (sale.taxMinor != 0) _totalRow('Tax', sale.taxMinor),
            pw.Divider(),
            _totalRow('Total', sale.totalMinor, bold: true),
            _totalRow('Paid', sale.amountPaidMinor),
            if (sale.changeMinor != 0) _totalRow('Change', sale.changeMinor),
            if (sale.amountDueMinor != 0) _totalRow('Due', sale.amountDueMinor),
          ],
        ),
      ),
    );
  }

  pw.Widget _footer() {
    final footer = settings['receipt_footer']?.trim() ?? '';
    return pw.Center(
      child: pw.Text(
        footer.isEmpty ? 'Thank you for your purchase' : footer,
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    );
  }
}
