import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../categories/data/category_repository.dart';
import '../../categories/domain/category.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

enum _StockStatus { notTracked, out, low, inStock }

extension _StockStatusInfo on _StockStatus {
  String get label => switch (this) {
        _StockStatus.notTracked => 'Not tracked',
        _StockStatus.out => 'Out of stock',
        _StockStatus.low => 'Low stock',
        _StockStatus.inStock => 'In stock',
      };

  Color get color => switch (this) {
        _StockStatus.notTracked => const Color(0xFF646464),
        _StockStatus.out => const Color(0xFFB00020),
        _StockStatus.low => const Color(0xFFB86E00),
        _StockStatus.inStock => const Color(0xFF1B7F37),
      };
}

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
    final saved = await AppNavigator.toProductForm<bool>(
      context,
      productUuid: product?.uuid,
    );
    if (saved == true) await _load();
  }

  _StockStatus _statusOf(Product product) {
    if (!product.trackStock) return _StockStatus.notTracked;
    if (product.stockQuantity <= 0) return _StockStatus.out;
    if (product.reorderLevel > 0 &&
        product.stockQuantity <= product.reorderLevel) {
      return _StockStatus.low;
    }
    return _StockStatus.inStock;
  }

  List<Product> get _visible {
    final query = _query.trim().toLowerCase();
    return _products.where((product) {
      if (_categoryId != null && product.categoryId != _categoryId) {
        return false;
      }
      final status = _statusOf(product);
      if (_lowStockOnly &&
          status != _StockStatus.low &&
          status != _StockStatus.out) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _archive(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${product.name}?'),
        content: const Text(
            'Archived products are hidden from sales and stay in past receipts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result =
        await context.read<ProductRepository>().archive(product.uuid);
    if (!mounted) return;
    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result.failureOrNull?.message ?? 'Unable to archive')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Archived ${product.name}')),
    );
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
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: status.color
                                            .withValues(alpha: 0.12),
                                        child: Text(
                                          product.name.isEmpty
                                              ? '?'
                                              : product.name[0].toUpperCase(),
                                          style: TextStyle(
                                              color: status.color,
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
                                          Text(
                                            [
                                              if (product.sku != null &&
                                                  product.sku!.isNotEmpty)
                                                'SKU ${product.sku}',
                                              if (product.trackStock)
                                                'Stock ${product.stockQuantity.toStringAsFixed(0)}',
                                              status.label,
                                            ].join(' · '),
                                            style:
                                                TextStyle(color: status.color),
                                          ),
                                        ],
                                      ),
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
                                          } else if (value == 'archive') {
                                            await _archive(product);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('Edit')),
                                          PopupMenuItem<String>(
                                              value: 'adjust',
                                              child: Text('Adjust stock')),
                                          PopupMenuItem<String>(
                                              value: 'archive',
                                              child: Text('Archive')),
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
