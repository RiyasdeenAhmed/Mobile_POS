import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../pos/domain/cart_controller.dart';
import '../../pos/domain/cart_item.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = <Product>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final repository = context.read<ProductRepository>();
    final products = await repository.search(_searchController.text);
    if (!mounted) return;
    setState(() {
      _products = products;
      _loading = false;
    });
  }

  void _addToCart(Product product) {
    final cart = context.read<CartController>();
    cart.addItem(CartItem.fromProduct(product));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.name}'),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartController>();
    final totals = cart.totals;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => AppNavigator.toCart(context),
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products or scan barcode',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _loadProducts(),
              onSubmitted: (_) => _loadProducts(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products found',
                        message: 'Add inventory or refine your search.',
                        action: ElevatedButton(
                          onPressed: () => AppNavigator.toProducts(context),
                          child: const Text('Manage products'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _products.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = _products[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              [
                                if (product.sku != null) product.sku!,
                                if (product.barcode != null) product.barcode!,
                                'Stock ${product.stockQuantity.toStringAsFixed(0)}',
                              ].join(' · '),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                MoneyText(
                                  amountMinor: product.sellingPriceMinor,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  product.trackStock
                                      ? (product.stockQuantity > 0
                                          ? 'In stock'
                                          : 'Out of stock')
                                      : 'Not tracked',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            onTap:
                                product.trackStock && product.stockQuantity <= 0
                                    ? null
                                    : () => _addToCart(product),
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
                        Text('Cart', style: theme.textTheme.titleSmall),
                        Text(
                          '${totals.itemCount} items',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text('Total', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 8),
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
