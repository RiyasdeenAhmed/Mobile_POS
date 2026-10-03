import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  int _parseMinor(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final negative = cleaned.startsWith('-');
    final body = negative ? cleaned.substring(1) : cleaned;
    final parts = body.split('.');
    final major = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    var cents = 0;
    if (parts.length > 1) {
      var centsPart = parts[1];
      if (centsPart.length == 1) centsPart = '${centsPart}0';
      if (centsPart.length > 2) centsPart = centsPart.substring(0, 2);
      cents = int.tryParse(centsPart) ?? 0;
    }
    final minor = major * 100 + cents;
    return negative ? -minor : minor;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = context.read<ProductRepository>();
    final result = await repository.create(
      name: _nameController.text,
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      costPriceMinor: _parseMinor(_costController.text),
      sellingPriceMinor: _parseMinor(_priceController.text),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (Product product) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created ${product.name}')),
        );
        Navigator.of(context).pop(true);
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(labelText: 'SKU (optional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcodeController,
              decoration:
                  const InputDecoration(labelText: 'Barcode (optional)'),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costController,
              decoration: const InputDecoration(
                labelText: 'Cost price',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                try {
                  final minor = _parseMinor(value);
                  if (minor < 0) return 'Cannot be negative';
                } catch (_) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Selling price',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                try {
                  final minor = _parseMinor(value);
                  if (minor < 0) return 'Cannot be negative';
                } catch (_) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _priceController,
              builder: (context, value, _) {
                final minor = _parseMinor(value.text);
                return Text(
                  'Preview: ${MoneyFormat.format(minor)}',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Save product'),
            ),
          ],
        ),
      ),
    );
  }
}
