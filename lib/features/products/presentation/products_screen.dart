import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ProductRepository>();
    return FutureBuilder<List<Product>>(
      future: repository.list(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Product>[];
        if (products.isEmpty) {
          return EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No products yet',
            message: 'Add your first product to start selling.',
            action: ElevatedButton.icon(
              onPressed: () => AppNavigator.toProductForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add product'),
            ),
          );
        }
        return ListView.separated(
          itemCount: products.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final product = products[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(
                  product.name.isEmpty ? '?' : product.name[0].toUpperCase(),
                ),
              ),
              title: Text(product.name),
              subtitle: Text(
                [
                  if (product.sku != null && product.sku!.isNotEmpty)
                    'SKU ${product.sku}',
                  if (product.barcode != null && product.barcode!.isNotEmpty)
                    product.barcode!,
                ].join(' · '),
              ),
              onTap: () => AppNavigator.toProductForm(context),
            );
          },
        );
      },
    );
  }
}
