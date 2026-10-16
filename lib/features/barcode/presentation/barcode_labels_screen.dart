import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/app_database.dart';
import '../../../core/platform/retail_files.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/barcode_label_service.dart';

class BarcodeLabelsScreen extends StatefulWidget {
  const BarcodeLabelsScreen({super.key, this.productUuid});
  final String? productUuid;
  @override
  State<BarcodeLabelsScreen> createState() => _BarcodeLabelsScreenState();
}

class _BarcodeLabelsScreenState extends State<BarcodeLabelsScreen> {
  List<Product> _products = [];
  Product? _product;
  bool _busy = false, _price = true;
  String? _message;
  final _width = TextEditingController(text: '50'),
      _height = TextEditingController(text: '30'),
      _copies = TextEditingController(text: '1');
  BarcodeLabelService get service =>
      BarcodeLabelService(context.read<AppDatabase>());
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final products = await context.read<ProductRepository>().list();
      if (mounted) {
        setState(() {
          _products = products;
          _product = products
              .where((p) => p.uuid == (widget.productUuid ?? _product?.uuid))
              .firstOrNull;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Could not load products');
    }
  }

  @override
  void dispose() {
    _width.dispose();
    _height.dispose();
    _copies.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _message =
            'Could not complete action. Check barcode, dimensions (30–150 × 20–150 mm), copies (1–100), and file access.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generate() async {
    final product = _product;
    if (product == null) return;
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Create barcode?'),
                content:
                    Text('Save a unique internal barcode for ${product.name}?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Create barcode'))
                ]));
    if (yes == true && mounted) {
      await _run(() async {
        await service.ensureBarcode(product.uuid);
        await _load();
      });
    }
  }

  Future<void> _export(bool png) async {
    await _run(() async {
      final p = _product!;
      final w = double.parse(_width.text), h = double.parse(_height.text);
      final n = int.parse(_copies.text);
      BarcodeLabelService.validate(p.barcode!, w, h, n);
      final bytes = png
          ? await service.png(p, width: w, height: h, price: _price)
          : await service.pdf(p, width: w, height: h, copies: n, price: _price);
      final result = await RetailFiles().save(
          name: 'label-${p.uuid}.${png ? 'png' : 'pdf'}',
          bytes: bytes,
          mime: png ? 'image/png' : 'application/pdf');
      if (result != null && mounted) {
        setState(() => _message = png
            ? 'PNG saved (one label; set copies in the printer app)'
            : 'PDF saved with $n labels');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Barcode Labels')),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        DropdownButtonFormField<String>(
            initialValue: _product?.uuid,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Product'),
            items: _products
                .map((p) => DropdownMenuItem(
                    value: p.uuid,
                    child: Text(p.name, overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _busy
                ? null
                : (v) => setState(
                    () => _product = _products.firstWhere((p) => p.uuid == v))),
        const SizedBox(height: 20),
        if (_product != null && (_product!.barcode?.isEmpty ?? true))
          FilledButton(
              onPressed: _busy ? null : _generate,
              child: const Text('Create Barcode')),
        if (_product?.barcode?.isNotEmpty ?? false) ...[
          AspectRatio(
              aspectRatio: (double.tryParse(_width.text) ?? 50).clamp(30, 150) /
                  (double.tryParse(_height.text) ?? 30).clamp(20, 150),
              child: CustomPaint(painter: LabelPainter(_product!, _price))),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: 130,
                child: TextField(
                    controller: _width,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Width (mm)'),
                    onChanged: (_) => setState(() {}))),
            SizedBox(
                width: 130,
                child: TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Height (mm)'),
                    onChanged: (_) => setState(() {}))),
            SizedBox(
                width: 130,
                child: TextField(
                    controller: _copies,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Copies')))
          ]),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _price,
              onChanged: (v) => setState(() => _price = v),
              title: const Text('Include selling price')),
          Wrap(spacing: 12, children: [
            FilledButton(
                onPressed: _busy ? null : () => _export(false),
                child: const Text('Export PDF')),
            OutlinedButton(
                onPressed: _busy ? null : () => _export(true),
                child: const Text('Export PNG'))
          ]),
        ],
        const SizedBox(height: 20),
        OutlinedButton.icon(
            onPressed:
                _busy ? null : () => _run(() => RetailFiles().openBarcodeApp()),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open barcode app')),
        const Text(
            'On Android, open the linked app and manually import your label file or enter the saved barcode. Printer setup and printing happen in that app.'),
        if (_busy) const LinearProgressIndicator(),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.only(top: 16), child: Text(_message!)),
      ]));
}
