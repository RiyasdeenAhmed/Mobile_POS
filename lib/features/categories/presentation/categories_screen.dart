import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: const EmptyState(
        icon: Icons.category_outlined,
        title: 'No categories yet',
        message: 'Organize products into categories when inventory is ready.',
      ),
    );
  }
}
