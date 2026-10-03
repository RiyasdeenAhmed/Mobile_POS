import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/cart_controller.dart';
import '../domain/cart_item.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final TextEditingController _noteController;
  TextEditingController? _discountController;

  @override
  void initState() {
    super.initState();
    _noteController =
        TextEditingController(text: context.read<CartController>().note);
  }

  @override
  void dispose() {
    _noteController.dispose();
    // The dialog may still be animating out when showDialog resolves, so
    // the discount controller only dies with this screen.
    _discountController?.dispose();
    super.dispose();
  }

  void _showLimit(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  Future<void> _editDiscount(CartItem item) async {
    _discountController?.dispose();
    final controller = TextEditingController(
      text: item.discountMinor == 0
          ? ''
          : (item.discountMinor % 100 == 0
              ? '${item.discountMinor ~/ 100}'
              : '${item.discountMinor ~/ 100}.${item.discountMinor % 100}'),
    );
    int? saved;
    final ok = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Discount — ${item.productName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Line discount',
                hintText: '0.00',
                helperText:
                    'Line total ${MoneyFormat.format(item.lineGrossMinor)}',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      saved = _parseMinor(controller.text);
    }
    _discountController = controller;
    if (saved == null || !mounted) return;

    final cart = context.read<CartController>();
    if (saved > item.lineGrossMinor) {
      _showLimit('Discount cannot exceed the line total');
      return;
    }
    cart.setDiscount(item.productUuid, saved);
    setState(() {});
  }

  static int _parseMinor(String input) {
    final cleaned = input.trim().replaceAll(',', '');
    if (cleaned.isEmpty) return 0;
    final parts = cleaned.split('.');
    final major = int.tryParse(parts[0].isEmpty ? '0' : parts[0]) ?? 0;
    var cents = 0;
    if (parts.length > 1) {
      var centsPart = parts[1];
      if (centsPart.length == 1) centsPart = '${centsPart}0';
      if (centsPart.length > 2) centsPart = centsPart.substring(0, 2);
      cents = int.tryParse(centsPart) ?? 0;
    }
    return major * 100 + cents;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartController>();
    final totals = cart.totals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart'),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: () {
                cart.clear();
                _noteController.clear();
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: cart.isEmpty
                ? EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart is empty',
                    message: 'Add products from New Sale to build a cart.',
                    action: ElevatedButton(
                      onPressed: () => AppNavigator.toNewSale(context),
                      child: const Text('Back to New Sale'),
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final atCap =
                          item.trackStock && item.quantity >= item.maxQuantity;
                      return _CartLine(
                        item: item,
                        atStockLimit: atCap,
                        onIncrement: () {
                          final result = cart.increment(item.productUuid);
                          if (result == CartChangeResult.atLimit ||
                              result == CartChangeResult.capped) {
                            _showLimit('Only '
                                '${item.maxQuantity.toStringAsFixed(0)} '
                                'in stock');
                          }
                        },
                        onDecrement: () => cart.setQuantity(
                            item.productUuid, item.quantity - 1),
                        onRemove: () => cart.removeItem(item.productUuid),
                        onDiscount: () => _editDiscount(item),
                      );
                    },
                  ),
          ),
          if (cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _noteController,
                maxLength: 200,
                decoration: const InputDecoration(
                  counterText: '',
                  labelText: 'Order note (optional)',
                  hintText: 'e.g. Pack separately',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                onChanged: (value) => cart.note = value,
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subtotal', style: theme.textTheme.titleSmall),
                            Text(
                              [
                                '${totals.itemCount} '
                                    'item${totals.itemCount == 1 ? '' : 's'}',
                                if (totals.discountMinor > 0)
                                  'Discount ${MoneyFormat.format(totals.discountMinor)}',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      MoneyText(
                        amountMinor: totals.totalMinor,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => AppNavigator.toCheckout(context),
                    child: const Text('Proceed to Checkout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  final CartItem item;
  final bool atStockLimit;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;
  final VoidCallback onDiscount;

  const _CartLine({
    required this.item,
    required this.atStockLimit,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    required this.onDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.productName, style: theme.textTheme.titleMedium),
                    Text(
                      [
                        '${MoneyFormat.format(item.unitPriceMinor)} each',
                        if (item.discountMinor > 0)
                          'Discount ${MoneyFormat.format(item.discountMinor)}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (atStockLimit)
                      Text(
                        'Maximum stock reached',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFFB86E00),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Decrease',
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                item.quantity == item.quantity.truncateToDouble()
                    ? '${item.quantity.round()}'
                    : '${item.quantity}',
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                tooltip: 'Increase',
                onPressed: atStockLimit ? null : onIncrement,
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onDiscount,
                icon: const Icon(Icons.percent, size: 18),
                label: const Text('Discount'),
              ),
              const Spacer(),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: MoneyText(
                      amountMinor: item.lineTotalMinor,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
