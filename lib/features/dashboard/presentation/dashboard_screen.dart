import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _open(BuildContext context, String route) {
    AppNavigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: QubeXCoreColors.primaryBlue,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start a sale or open key records.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.point_of_sale,
                color: Colors.white,
                size: 36,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            _ActionTile(
              icon: Icons.point_of_sale,
              title: 'New Sale',
              subtitle: 'Open cart',
              color: QubeXCoreColors.primaryBlue,
              onTap: () => _open(context, AppRoutes.newSale),
            ),
            _ActionTile(
              icon: Icons.receipt_long,
              title: 'Sales',
              subtitle: 'History',
              color: QubeXCoreColors.primaryDark,
              onTap: () => _open(context, AppRoutes.sales),
            ),
            _ActionTile(
              icon: Icons.inventory_2,
              title: 'Products',
              subtitle: 'Catalog',
              color: QubeXCoreColors.primaryDarker,
              onTap: () => _open(context, AppRoutes.products),
            ),
            _ActionTile(
              icon: Icons.people,
              title: 'Customers',
              subtitle: 'Accounts',
              color: QubeXCoreColors.successGreen,
              onTap: () => _open(context, AppRoutes.customers),
            ),
            _ActionTile(
              icon: Icons.warehouse,
              title: 'Inventory',
              subtitle: 'Stock',
              color: QubeXCoreColors.warningOrange,
              onTap: () => _open(context, AppRoutes.inventory),
            ),
            _ActionTile(
              icon: Icons.settings,
              title: 'Settings',
              subtitle: 'Store',
              color: QubeXCoreColors.qubexDarkGray,
              onTap: () => _open(context, AppRoutes.settings),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Recent sales', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No sales yet', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Completed sales will appear here.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
