import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/money_text.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../data/dashboard_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardMetrics? _metrics;
  List<Sale> _recent = <Sale>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    DashboardMetrics? metrics;
    List<Sale> recent = <Sale>[];
    try {
      metrics = await context.read<DashboardRepository>().metrics();
      if (!mounted) return;
      recent = await context.read<SaleRepository>().list(limit: 5);
    } catch (_) {
      // Best-effort load: keep the previous state on failure.
      metrics = _metrics;
      recent = _recent;
    }
    if (!mounted) return;
    setState(() {
      _metrics = metrics;
      _recent = recent;
      _loading = false;
    });
  }

  void _open(BuildContext context, String route) {
    AppNavigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _metrics;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
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
          Text('Today', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (metrics != null) ...[
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.6,
              children: [
                _MetricCard(
                  icon: Icons.point_of_sale,
                  label: "Today's sales",
                  value: MoneyFormat.format(metrics.todaySalesTotalMinor),
                ),
                _MetricCard(
                  icon: Icons.receipt_long,
                  label: 'Transactions',
                  value: '${metrics.todayTransactionCount}',
                ),
                _MetricCard(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Outstanding credit',
                  value: MoneyFormat.format(metrics.outstandingCreditMinor),
                ),
                _MetricCard(
                  icon: Icons.warning_amber_outlined,
                  label: 'Low stock',
                  value: '${metrics.lowStockCount}',
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Text('Recent transactions', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_recent.isEmpty)
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
                          Text(
                            'No sales yet',
                            style: theme.textTheme.titleMedium,
                          ),
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
            )
          else
            ..._recent.map(
              (sale) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(sale.invoiceNumber),
                  subtitle: Text(
                    [
                      sale.paymentMethod.toUpperCase(),
                      sale.saleAt,
                    ].join(' · '),
                  ),
                  trailing: MoneyText(amountMinor: sale.totalMinor),
                  onTap: () => AppNavigator.toSaleDetail(
                    context,
                    saleUuid: sale.uuid,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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
