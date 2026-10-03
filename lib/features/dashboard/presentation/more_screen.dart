import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../staff/application/staff_session.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _confirmSignOut(BuildContext context) {
    final session = context.read<StaffSession>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out'),
        content: Text('Sign out of ${session.displayName ?? "this account"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              session.signOut();
              AppNavigator.replaceNamed(context, AppRoutes.login);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (session.isSignedIn)
          ListTile(
            leading: CircleAvatar(
              child: Text(
                (session.displayName ?? '?').isEmpty
                    ? '?'
                    : session.displayName![0].toUpperCase(),
              ),
            ),
            title: Text(session.displayName ?? ''),
            subtitle: Text(
              session.isAdmin ? 'Administrator' : 'Cashier',
            ),
          ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: const Text('Settings'),
          subtitle: const Text('Store name and currency'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.toSettings(context),
        ),
        ListTile(
          leading: const Icon(Icons.people_outline),
          title: const Text('Staff'),
          subtitle: const Text('Cashiers and administrators'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => AppNavigator.toStaffManagement(context),
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
          leading: Icon(
            Icons.logout,
            color:
                session.isSignedIn ? Theme.of(context).colorScheme.error : null,
          ),
          title: const Text('Sign out'),
          onTap: session.isSignedIn ? () => _confirmSignOut(context) : null,
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          subtitle: const Text('QubeXCore POS Phase 1'),
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
