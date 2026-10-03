import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productUuid});

  final String? productUuid;

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
  final _stockController = TextEditingController();
  final _reorderController = TextEditingController(text: '0');

  bool _saving = false;
  bool _trackStock = true;
  int? _categoryId;
  double _currentStock = 0;
  Product? _existing;
  List<Category> _categories = const <Category>[];
  String? _loadError;

  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final categoryRepository = context.read<CategoryRepository>();
      final productRepository = context.read<ProductRepository>();
      final categories = await categoryRepository.list(includeArchived: true);
      Product? product;
      if (widget.productUuid != null) {
        product = await productRepository.findByUuid(widget.productUuid!);
        if (product == null) {
          if (!mounted) return;
          setState(() => _loadError = 'Product not found');
          return;
        }
        _applyExisting(product);
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _existing = product;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = '$error');
    }
  }

  void _applyExisting(Product product) {
    _nameController.text = product.name;
    _skuController.text = product.sku ?? '';
    _barcodeController.text = product.barcode ?? '';
    _costController.text = _minorToInput(product.costPriceMinor);
    _priceController.text = _minorToInput(product.sellingPriceMinor);
    _stockController.text = _formatQuantity(product.stockQuantity);
    _reorderController.text = _formatQuantity(product.reorderLevel);
    _trackStock = product.trackStock;
    _categoryId = product.categoryId;
    _currentStock = product.stockQuantity;
  }

  static String _minorToInput(int minor) =>
      (minor % 100 == 0) ? '${minor ~/ 100}' : '${minor ~/ 100}.${minor % 100}';

  static String _formatQuantity(double quantity) =>
      quantity == quantity.truncateToDouble()
          ? '${quantity.round()}'
          : '$quantity';

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

  String? _validatePrice(String? value, {bool required = false}) {
    if (value == null || value.trim().isEmpty) {
      return required ? 'Selling price is required' : null;
    }
    try {
      final minor = _parseMinor(value);
      if (minor < 0) return 'Cannot be negative';
    } catch (_) {
      return 'Enter a valid amount';
    }
    return null;
  }

  String? _validateStock(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = double.tryParse(value.trim().replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid quantity';
    if (parsed < 0) return 'Cannot be negative';
    return null;
  }

  double _parseQuantity(String input) =>
      double.tryParse(input.trim().replaceAll(',', '')) ?? 0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = context.read<ProductRepository>();

    if (_isEdit) {
      final current = _existing!;
      final updated = Product(
        id: current.id,
        uuid: current.uuid,
        sku: _skuController.text.trim().isEmpty
            ? null
            : _skuController.text.trim(),
        barcode: _barcodeController.text.trim().isEmpty
            ? null
            : _barcodeController.text.trim(),
        name: _nameController.text,
        categoryId: _categoryId,
        costPriceMinor: _parseMinor(_costController.text),
        sellingPriceMinor: _parseMinor(_priceController.text),
        currency: current.currency,
        stockQuantity: current.stockQuantity,
        reorderLevel: _parseQuantity(_reorderController.text),
        trackStock: _trackStock,
        isActive: current.isActive,
        isArchived: current.isArchived,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      );
      final result = await repository.update(updated);
      if (!mounted) return;
      setState(() => _saving = false);
      result.when(
        success: (product) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Updated ${product.name}')),
          );
          Navigator.of(context).pop(true);
        },
        failure: (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        },
      );
      return;
    }

    final result = await repository.create(
      name: _nameController.text,
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      categoryId: _categoryId,
      costPriceMinor: _parseMinor(_costController.text),
      sellingPriceMinor: _parseMinor(_priceController.text),
      stockQuantity: _parseQuantity(_stockController.text),
      reorderLevel: _parseQuantity(_reorderController.text),
      trackStock: _trackStock,
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
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }
    if (widget.productUuid != null && _existing == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'New product')),
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
            DropdownButtonFormField<int?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('None')),
                ..._categories.where((c) => !c.isArchived).map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(c.name),
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
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
              validator: (value) => _validatePrice(value),
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
              validator: (value) => _validatePrice(value, required: true),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _reorderController,
              decoration: const InputDecoration(
                labelText: 'Reorder level',
                helperText: 'Low stock is flagged at or below this quantity',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => _validateStock(value),
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _stockController,
                decoration: const InputDecoration(
                  labelText: 'Opening stock',
                  hintText: '0',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => _validateStock(value),
              ),
            ] else ...[
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: Text(
                      'Current stock: ${_currentStock.toStringAsFixed(0)}'),
                  subtitle: const Text(
                      'Stock changes are recorded from the Inventory screen'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              value: _trackStock,
              contentPadding: EdgeInsets.zero,
              title: const Text('Track stock'),
              subtitle:
                  const Text('Turn off for services or non-stocked items'),
              onChanged: (value) => setState(() => _trackStock = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: Text(_saving
                  ? 'Saving...'
                  : _isEdit
                      ? 'Save changes'
                      : 'Save product'),
            ),
          ],
        ),
      ),
    );
  }
}
