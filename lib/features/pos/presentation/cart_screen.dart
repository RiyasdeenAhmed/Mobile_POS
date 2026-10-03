import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../domain/cart_controller.dart';
import '../domain/cart_item.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

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
              onPressed: () => cart.clear(),
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
                      return _CartLine(
                        item: item,
                        onChanged: (quantity) {
                          cart.setQuantity(item.productUuid, quantity);
                        },
                        onRemove: () => cart.removeItem(item.productUuid),
                      );
                    },
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Subtotal', style: theme.textTheme.titleSmall),
                        Text(
                          '${totals.itemCount} items',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  MoneyText(amountMinor: totals.totalMinor),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => AppNavigator.toCheckout(context),
                    child: const Text('Checkout'),
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
  final ValueChanged<double> onChanged;
  final VoidCallback onRemove;

  const _CartLine({
    required this.item,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(item.productName),
      subtitle: Text(
        [
          MoneyFormat.format(item.unitPriceMinor),
          if (item.discountMinor > 0)
            'Discount ${MoneyFormat.format(item.discountMinor)}',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onChanged(item.quantity - 1),
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            item.quantity.toString(),
            style: theme.textTheme.titleMedium,
          ),
          IconButton(
            onPressed: () => onChanged(item.quantity + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
          const SizedBox(width: 4),
          MoneyText(
            amountMinor: item.lineTotalMinor,
            style: theme.textTheme.titleSmall,
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
