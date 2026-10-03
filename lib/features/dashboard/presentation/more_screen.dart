import 'package:flutter/material.dart';

import '../../../app/routes.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          subtitle: const Text('Store name and currency'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.toSettings(context),
        ),
        ListTile(
          leading: const Icon(Icons.warehouse_outlined),
          title: const Text('Inventory'),
          subtitle: const Text('Stock levels and movements'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.toInventory(context),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Categories'),
          subtitle: const Text('Product categories'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.toCategories(context),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('QubeXCore POS Milestone 1'),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'QubeXCore POS',
              applicationVersion: '0.1.0',
              applicationLegalese: 'Offline-first retail POS',
            );
          },
        ),
      ],
    );
  }
}
