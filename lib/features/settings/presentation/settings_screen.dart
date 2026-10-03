import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/settings_repository.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repository = context.read<SettingsRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<Map<String, String>>(
        future: repository.loadCoreSettings(),
        builder: (context, snapshot) {
          final settings = snapshot.data ?? const <String, String>{};
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Store name'),
                subtitle: Text(
                  settings['store_name']?.isEmpty == true
                      ? 'Not set'
                      : settings['store_name'] ?? 'Not set',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('Currency'),
                subtitle: Text(
                  '${settings['currency_code'] ?? 'LKR'} (${settings['currency_symbol'] ?? r'$'})',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.tag),
                title: const Text('Invoice sequence'),
                subtitle: Text(settings['invoice_sequence'] ?? '0'),
              ),
              const ListTile(
                leading: Icon(Icons.lock_outline),
                title: Text('Staff accounts'),
                subtitle: Text('Local auth arrives in a later milestone'),
              ),
              const AboutListTile(
                icon: Icon(Icons.info_outline),
                applicationName: 'QubeXCore POS',
                applicationVersion: '0.1.0',
                applicationLegalese: 'Offline-first retail POS',
              ),
            ],
          );
        },
      ),
    );
  }
}
