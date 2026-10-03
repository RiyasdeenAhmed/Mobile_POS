import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/stock_movement_repository.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _lowStock = const <Product>[];
  List<Product> _all = const <Product>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final productRepository = context.read<ProductRepository>();
      final movementRepository = context.read<StockMovementRepository>();
      final low = await movementRepository.lowStockProducts();
      final all = await productRepository.list();
      if (!mounted) return;
      setState(() {
        _lowStock = low;
        _all = all;
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

  Future<void> _openAdjust(Product product) async {
    await AppNavigator.toStockAdjust(context, productUuid: product.uuid);
    if (mounted) await _load();
  }

  String _formatQuantity(double value) =>
      value == value.truncateToDouble() ? '${value.round()}' : '$value';

  Widget _productTile(Product product, {required bool showReorder}) {
    final out = product.stockQuantity <= 0;
    final low =
        product.trackStock && product.stockQuantity <= product.reorderLevel;
    final color = out
        ? const Color(0xFFB00020)
        : low
            ? const Color(0xFFB86E00)
            : const Color(0xFF1B7F37);
    final status = !product.trackStock
        ? 'Not tracked'
        : out
            ? 'Out of stock'
            : low
                ? 'Low stock'
                : 'In stock';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Text(
          product.name.isEmpty ? '?' : product.name[0].toUpperCase(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(product.name),
      subtitle: Text(
        [
          'Stock ${_formatQuantity(product.stockQuantity)}',
          if (showReorder)
            'Reorder at ${_formatQuantity(product.reorderLevel)}',
          status,
        ].join(' · '),
        style: TextStyle(color: color),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            MoneyFormat.format(product.sellingPriceMinor),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      onTap: () => _openAdjust(product),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Low stock (${_lowStock.length})'),
              const Tab(text: 'All products'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _lowStock.isEmpty
                ? const EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'Nothing is low on stock',
                    message:
                        'Products appear here when stock drops to the reorder level.',
                  )
                : ListView.separated(
                    itemCount: _lowStock.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _productTile(_lowStock[index], showReorder: true),
                  ),
            _all.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'No products yet',
                    message: 'Add products to track their stock levels.',
                  )
                : ListView.separated(
                    itemCount: _all.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        _productTile(_all[index], showReorder: false),
                  ),
          ],
        ),
      ),
    );
  }
}
