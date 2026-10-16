import 'package:flutter/material.dart';
import '../../features/products/domain/product.dart';
import '../theme/money_text.dart';
import 'stock_status.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onAdd});
  final Product product;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = resolveStockStatus(
        trackStock: product.trackStock,
        stock: product.stockQuantity,
        reorderLevel: product.reorderLevel);
    final out = status == StockStatus.out;
    const icons = [
      Icons.local_drink_outlined,
      Icons.shopping_basket_outlined,
      Icons.cookie_outlined,
      Icons.cleaning_services_outlined,
      Icons.inventory_2_outlined
    ];
    return Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: out ? null : onAdd,
            child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          child: Center(
                              child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Icon(
                                      icons[(product.categoryId ?? 4) %
                                          icons.length],
                                      size: 38,
                                      color: theme.colorScheme.primary)))),
                      const SizedBox(height: 8),
                      Text(product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                          out
                              ? 'Out of Stock'
                              : product.trackStock
                                  ? 'Stock ${product.stockQuantity}'
                                  : 'Not Tracked',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: status.readableColor(context))),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                            child: MoneyText(
                                amountMinor: product.sellingPriceMinor,
                                style: theme.textTheme.labelLarge)),
                        IconButton.filled(
                            onPressed: out ? null : onAdd,
                            tooltip: 'Add ${product.name}',
                            icon: const Icon(Icons.add))
                      ]),
                    ]))));
  }
}
