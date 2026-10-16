import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/stock_status.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final _searchController = TextEditingController();

  List<Product> _products = const <Product>[];
  List<Category> _categories = const <Category>[];
  String _query = '';
  int? _categoryId;
  bool _lowStockOnly = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final productRepository = context.read<ProductRepository>();
      final categoryRepository = context.read<CategoryRepository>();
      final products = await productRepository.list();
      final categories = await categoryRepository.list();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = categories;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _openForm({Product? product}) async {
    // Push untyped: onGenerateRoute builds MaterialPageRoute<dynamic> and a
    // typed pushNamed<bool> would fail the Route<T?> cast at runtime.
    final saved = await AppNavigator.toProductForm(
      context,
      productUuid: product?.uuid,
    );
    if (saved == true) await _load();
  }

  StockStatus _statusOf(Product product) {
    return resolveStockStatus(
      trackStock: product.trackStock,
      stock: product.stockQuantity,
      reorderLevel: product.reorderLevel,
    );
  }

  List<Product> get _visible {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      if (_categoryId != null && product.categoryId != _categoryId) {
        return false;
      }
      final status = _statusOf(product);
      if (_lowStockOnly &&
          status != StockStatus.low &&
          status != StockStatus.out) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _archive(Product product) async {
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${product.name}?'),
        content: const Text(
            'This removes the product from the catalog and new sales. Past receipts and stock records are preserved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete product'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result =
        await context.read<ProductRepository>().archive(product.uuid);
    if (!mounted) return;
    if (result.isFailure) {
      showAppSnack(
        context,
        result.failureOrNull?.message ?? 'Unable to delete product',
        kind: AppSnackKind.error,
      );
      return;
    }
    showAppSnack(context, 'Deleted ${product.name}');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'New Sale',
            icon: const Icon(Icons.point_of_sale),
            onPressed: () => AppNavigator.toNewSale(context),
          ),
          IconButton(
            tooltip: 'Categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await AppNavigator.toCategories(context);
              if (mounted) await _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search name, SKU or barcode',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _query = '');
                                  },
                                ),
                        ),
                        onChanged: (value) => setState(() => _query = value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int?>(
                                value: _categoryId,
                                isExpanded: true,
                                hint: const Text('All categories'),
                                items: [
                                  const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('All categories')),
                                  ..._categories.map(
                                    (c) => DropdownMenuItem<int?>(
                                      value: c.id,
                                      child: Text(
                                        c.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _categoryId = value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Low stock'),
                            selected: _lowStockOnly,
                            avatar: Icon(
                              Icons.warning_amber_outlined,
                              size: 18,
                              color: _lowStockOnly
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : null,
                            ),
                            onSelected: (value) =>
                                setState(() => _lowStockOnly = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: _products.isEmpty
                          ? EmptyState(
                              icon: Icons.inventory_2_outlined,
                              title: 'No products yet',
                              message:
                                  'Add your first product to start selling.',
                              action: ElevatedButton.icon(
                                onPressed: () => _openForm(),
                                icon: const Icon(Icons.add),
                                label: const Text('Add product'),
                              ),
                            )
                          : visible.isEmpty
                              ? const EmptyState(
                                  icon: Icons.search_off,
                                  title: 'No matching products',
                                  message:
                                      'Try a different search or clear filters.',
                                )
                              : ListView.separated(
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final product = visible[index];
                                    final status = _statusOf(product);
                                    final statusColor = status.readableColor(
                                      context,
                                    );
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            statusColor.withValues(alpha: 0.12),
                                        child: Text(
                                          product.name.isEmpty
                                              ? '?'
                                              : product.name[0].toUpperCase(),
                                          style: TextStyle(
                                              color: statusColor,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      title: Text(product.name),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            MoneyFormat.format(
                                                product.sellingPriceMinor),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  [
                                                    if (product.sku != null &&
                                                        product.sku!.isNotEmpty)
                                                      'SKU ${product.sku}',
                                                    if (product.trackStock)
                                                      'Stock ${product.stockQuantity.toStringAsFixed(0)}',
                                                  ].join(' · '),
                                                  style: TextStyle(
                                                    color: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.color,
                                                  ),
                                                ),
                                              ),
                                              StockStatusBadge(status: status),
                                            ],
                                          ),
                                        ],
                                      ),
                                      onTap: () => _openForm(product: product),
                                      trailing: PopupMenuButton<String>(
                                        tooltip: 'Product actions',
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _openForm(product: product);
                                          } else if (value == 'adjust') {
                                            await AppNavigator.toStockAdjust(
                                              context,
                                              productUuid: product.uuid,
                                            );
                                            if (mounted) await _load();
                                          } else if (value == 'labels') {
                                            await AppNavigator.pushNamed(
                                                context,
                                                AppRoutes.barcodeLabels,
                                                arguments: product.uuid);
                                            if (mounted) await _load();
                                          } else if (value == 'archive') {
                                            await _archive(product);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem<String>(
                                              value: 'labels',
                                              child: Text('Barcode Labels')),
                                          PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          PopupMenuItem<String>(
                                              value: 'adjust',
                                              child: Text('Adjust stock')),
                                          PopupMenuItem<String>(
                                              value: 'archive',
                                              child: Row(children: [
                                                Icon(Icons.delete_outline),
                                                SizedBox(width: 8),
                                                Text('Delete product')
                                              ])),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
    );
  }
}
