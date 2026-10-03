import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: const EmptyState(
        icon: Icons.warehouse_outlined,
        title: 'Inventory tracking',
        message:
            'Stock levels, movements, and reorder alerts arrive in a later milestone.',
      ),
    );
  }
}
