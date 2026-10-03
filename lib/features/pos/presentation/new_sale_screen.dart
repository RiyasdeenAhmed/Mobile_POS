import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/cart_controller.dart';
import '../domain/cart_item.dart';

class NewSaleScreen extends StatefulWidget {
  const NewSaleScreen({super.key});

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  final _searchController = TextEditingController();
  List<Product> _products = <Product>[];
  List<Category> _categories = const <Category>[];
  int? _selectedCategoryId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final productRepository = context.read<ProductRepository>();
    final categoryRepository = context.read<CategoryRepository>();
    final products = await productRepository.search(_searchController.text);
    final categories = await categoryRepository.list();
    if (!mounted) return;
    setState(() {
      _products = products;
      _categories = categories;
      _loading = false;
    });
  }

  List<Product> get _visibleProducts {
    if (_selectedCategoryId == null) return _products;
    return _products
        .where((product) => product.categoryId == _selectedCategoryId)
        .toList();
  }

  void _addToCart(Product product) {
    final cart = context.read<CartController>();
    final result = cart.addItem(CartItem.fromProduct(product));
    final message = switch (result) {
      CartChangeResult.ok => 'Added ${product.name}',
      CartChangeResult.capped => 'Added ${product.name} — only '
          '${product.stockQuantity.toStringAsFixed(0)} in stock',
      CartChangeResult.atLimit => 'Only '
          '${product.stockQuantity.toStringAsFixed(0)} in stock',
      CartChangeResult.outOfStock => '${product.name} is out of stock',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartController>();
    final totals = cart.totals;
    final visible = _visibleProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sale'),
        actions: [
          IconButton(
            tooltip: 'Scan',
            onPressed: () => AppNavigator.toScan(context),
            icon: const Icon(Icons.qr_code_scanner),
          ),
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
              onChanged: (_) => _loadData(),
              onSubmitted: (_) => _loadData(),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('All'),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) =>
                        setState(() => _selectedCategoryId = null),
                  ),
                ),
                ..._categories.map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.name),
                      selected: _selectedCategoryId == category.id,
                      onSelected: (_) => setState(
                        () => _selectedCategoryId = category.id,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: _products.isEmpty
                            ? 'No products found'
                            : 'Nothing in this category',
                        message: _products.isEmpty
                            ? 'Add inventory or refine your search.'
                            : 'Pick another category or clear your search.',
                        action: ElevatedButton(
                          onPressed: () => AppNavigator.toProducts(context),
                          child: const Text('Manage products'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final product = visible[index];
                          final out =
                              product.trackStock && product.stockQuantity <= 0;
                          final low = product.trackStock &&
                              product.reorderLevel > 0 &&
                              product.stockQuantity <= product.reorderLevel;
                          final stockColor = out
                              ? const Color(0xFFB00020)
                              : low
                                  ? const Color(0xFFB86E00)
                                  : theme.colorScheme.outline;
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(
                              [
                                if (product.sku != null) product.sku!,
                                if (product.barcode != null) product.barcode!,
                                product.trackStock
                                    ? 'Stock ${product.stockQuantity.toStringAsFixed(0)}'
                                        '${out ? ' · Out of stock' : low ? ' · Low stock' : ''}'
                                    : 'Not tracked',
                              ].join(' · '),
                              style: TextStyle(color: stockColor),
                            ),
                            trailing: MoneyText(
                              amountMinor: product.sellingPriceMinor,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            onTap: out ? null : () => _addToCart(product),
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
                    child: Text(
                      '${totals.itemCount} '
                      'item${totals.itemCount == 1 ? '' : 's'}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  MoneyText(
                    amountMinor: totals.totalMinor,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: cart.isEmpty
                        ? null
                        : () => AppNavigator.toCart(context),
                    child: const Text('View Cart'),
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
