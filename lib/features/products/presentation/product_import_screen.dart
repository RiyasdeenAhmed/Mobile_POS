import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/retail_files.dart';
import '../data/product_csv_service.dart';

class ProductImportScreen extends StatefulWidget {
  const ProductImportScreen({super.key});
  @override
  State<ProductImportScreen> createState() => _ProductImportScreenState();
}

class _ProductImportScreenState extends State<ProductImportScreen> {
  List<CsvProductRow> _rows = [];
  bool _busy = false;
  String? _message;
  ProductCsvService get service =>
      ProductCsvService(context.read<AppDatabase>());
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        setState(() => _message = e is FormatException
            ? e.message
            : 'Could not complete import or file operation. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Import products')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text(
            'Import new products from a UTF-8 CSV. Existing SKU or barcode matches are skipped. Prices use the store currency.'),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final csv = await RetailFiles().readCsv();
                        if (csv == null) return;
                        final rows = await service.preview(csv);
                        if (mounted) setState(() => _rows = rows);
                      }),
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose CSV')),
          OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                        final saved = await RetailFiles().save(
                            name: 'products_template.csv',
                            bytes: utf8.encode(ProductCsvService.template),
                            mime: 'text/csv');
                        if (saved != null && mounted) {
                          setState(() => _message = 'Template saved');
                        }
                      }),
              child: const Text('Download template')),
        ]),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(padding: const EdgeInsets.all(16), child: Text(_message!)),
        ..._rows.map((r) => Card(
            margin: const EdgeInsets.only(top: 8),
            child: CheckboxListTile(
                value: !r.excluded && !r.duplicate,
                onChanged: _busy || r.duplicate
                    ? null
                    : (v) => setState(() => r.excluded = !(v ?? false)),
                title: Text('Row ${r.number}: ${r.values['name']}'),
                subtitle: Text(r.error ??
                    (r.duplicate
                        ? 'Existing product — skipped'
                        : 'New product · ${r.values['selling_price']}'))))),
        if (_rows.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FilledButton(
                  onPressed:
                      _busy || _rows.any((r) => r.error != null && !r.excluded)
                          ? null
                          : () => _run(() async {
                                final count = await service.commit(_rows);
                                if (mounted) {
                                  setState(() {
                                    _rows = [];
                                    _message =
                                        '$count products imported. Existing products were preserved.';
                                  });
                                }
                              }),
                  child: const Text('Import selected products'))),
      ]));
}
