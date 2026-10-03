import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../staff/application/staff_session.dart';
import '../data/stock_movement_repository.dart';
import '../domain/stock_movement.dart';

class StockAdjustScreen extends StatefulWidget {
  const StockAdjustScreen({super.key, required this.productUuid});

  final String productUuid;

  @override
  State<StockAdjustScreen> createState() => _StockAdjustScreenState();
}

class _StockAdjustScreenState extends State<StockAdjustScreen> {
  static const _increaseTypes = {'purchase', 'adjustment_in'};

  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  String _movementType = 'adjustment_in';
  Product? _product;
  List<StockMovement> _movements = const <StockMovement>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final productRepository = context.read<ProductRepository>();
      final movementRepository = context.read<StockMovementRepository>();
      final product = await productRepository.findByUuid(widget.productUuid);
      if (product == null) {
        if (!mounted) return;
        setState(() => _error = 'Product not found');
        return;
      }
      final movements = await movementRepository.listByProduct(product.id ?? 0);
      if (!mounted) return;
      setState(() {
        _product = product;
        _movements = movements;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    }
  }

  bool get _isIncrease => _increaseTypes.contains(_movementType);
  String get _signLabel => _isIncrease ? '+' : '−';

  double get _enteredQuantity =>
      double.tryParse(_quantityController.text.trim().replaceAll(',', '')) ?? 0;

  double get _signedChange =>
      _isIncrease ? _enteredQuantity : -_enteredQuantity;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final product = _product;
    if (product == null) return;

    setState(() => _saving = true);
    final repository = context.read<StockMovementRepository>();
    final result = await repository.adjustStock(
      productUuid: product.uuid,
      quantityChange: _signedChange,
      movementType: _movementType,
      note: _noteController.text.trim(),
      staffUuid: context.read<StaffSession>().staffUuid,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.failureOrNull!.message)),
      );
      return;
    }
    _quantityController.clear();
    _noteController.clear();
    _formKey.currentState?.reset();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Stock adjusted')),
    );
    await _load();
  }

  String _formatQuantity(double value) =>
      value == value.truncateToDouble() ? '${value.round()}' : '$value';

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();
    final canAdjust = session.isAdmin;

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventory')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final product = _product;
    if (product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nextStock = product.stockQuantity + _signedChange;

    return Scaffold(
      appBar: AppBar(
        title: Text(canAdjust ? 'Adjust stock' : 'Stock history'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(product.name),
              subtitle: Text(
                'Stock ${_formatQuantity(product.stockQuantity)} · '
                'Reorder at ${_formatQuantity(product.reorderLevel)}',
              ),
              trailing: Text(
                MoneyFormat.format(product.sellingPriceMinor),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (canAdjust) ...[
            const SizedBox(height: 16),
            Text('Adjustment', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _movementType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Movement type',
                      helperText: '+ adds stock · − removes stock',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'adjustment_in',
                          child: Text('Adjustment in (+)')),
                      DropdownMenuItem(
                          value: 'adjustment_out',
                          child: Text('Adjustment out (−)')),
                      DropdownMenuItem(
                          value: 'purchase', child: Text('Purchase (+)')),
                      DropdownMenuItem(
                          value: 'damage', child: Text('Damage (−)')),
                    ],
                    onChanged: (value) => setState(
                      () => _movementType = value ?? 'adjustment_in',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantityController,
                    decoration: InputDecoration(
                      labelText: 'Quantity',
                      hintText: '0',
                      suffixText: _signLabel,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Quantity is required';
                      final parsed = double.tryParse(text.replaceAll(',', ''));
                      if (parsed == null) return 'Enter a valid quantity';
                      if (parsed <= 0) {
                        return 'Quantity must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    nextStock < 0
                        ? 'This adjustment would take stock below zero'
                        : 'Stock ${_formatQuantity(product.stockQuantity)} '
                            '→ ${_formatQuantity(nextStock)} '
                            '($_signLabel${_formatQuantity(_enteredQuantity)})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: nextStock < 0
                              ? const Color(0xFFB00020)
                              : Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      helperText: 'Required — the reason for this adjustment',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'A note is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Record adjustment'),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            const Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Only admins can adjust stock'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Movement history',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_movements.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No stock movements yet.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _movements.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final movement = _movements[index];
                final increase = movement.isIncrease;
                final color = increase
                    ? const Color(0xFF1B7F37)
                    : const Color(0xFFB00020);
                return ListTile(
                  dense: true,
                  leading: Icon(
                    increase ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                  ),
                  title: Text(
                    '${increase ? '+' : '−'}'
                    '${_formatQuantity(movement.quantityChange.abs())} '
                    '${movement.movementType.replaceAll('_', ' ')}',
                    style: TextStyle(color: color),
                  ),
                  subtitle: Text(
                    [
                      'Stock after: ${_formatQuantity(movement.quantityAfter)}',
                      if (movement.note != null && movement.note!.isNotEmpty)
                        movement.note!,
                      if (movement.createdDateTime != null)
                        '${movement.createdDateTime!.toLocal()}'
                            .split('.')
                            .first,
                    ].join(' · '),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
