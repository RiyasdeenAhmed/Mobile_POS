import '../../profit/presentation/profit_screen.dart';
import '../../staff/application/staff_session.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/theme/app_ui.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
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

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  bool _searching = false;
  bool _searchError = false;
  int _searchRequest = 0;
  List<Product> _productResults = const <Product>[];
  List<Customer> _customerResults = const <Customer>[];
  List<Sale> _invoiceResults = const <Sale>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
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

  void _onQueryChanged(String value) {
    _searchDebounce?.cancel();
    final trimmed = value.trim();
    setState(() {
      _query = value;
      if (trimmed.isEmpty) {
        _searching = false;
        _searchError = false;
        _productResults = const <Product>[];
        _customerResults = const <Customer>[];
        _invoiceResults = const <Sale>[];
        return;
      }
      _searching = true;
      _searchError = false;
    });
    if (trimmed.isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _runSearch(trimmed);
    });
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequest;
    final productRepo = context.read<ProductRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final saleRepo = context.read<SaleRepository>();
    try {
      final products = await productRepo.search(query, limit: 8);
      final customers = await customerRepo.search(query, limit: 8);
      final invoices = await saleRepo.searchByInvoice(query, limit: 8);
      if (!mounted || requestId != _searchRequest) return;
      setState(() {
        _productResults = products;
        _customerResults = customers;
        _invoiceResults = invoices;
        _searching = false;
        _searchError = false;
      });
    } catch (_) {
      if (!mounted || requestId != _searchRequest) return;
      setState(() {
        _productResults = const <Product>[];
        _customerResults = const <Customer>[];
        _invoiceResults = const <Sale>[];
        _searching = false;
        _searchError = true;
      });
    }
  }

  void _open(BuildContext context, String route) {
    AppNavigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = _metrics;
    final searching = _query.trim().isNotEmpty;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: QubeXUi.pagePadding,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search products, customers, invoices',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (!searching) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Start a sale or open key records.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.point_of_sale,
                    color: Colors.white,
                    size: 48,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Narrow phones need a little more height for the card copy,
                // while wider phones benefit from a compact grid that reveals
                // the Today section without scrolling.
                final ratio = constraints.maxWidth < 400 ? 1.35 : 1.8;
                return GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: ratio,
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
                );
              },
            ),
            const SizedBox(height: 20),
            if (context.watch<StaffSession>().isAdmin) ...[
              const ProfitPanel(),
              const SizedBox(height: 12),
              const ProfitPanel(month: true),
              TextButton.icon(
                  onPressed: () => _open(context, AppRoutes.profit),
                  icon: const Icon(Icons.insights),
                  label: const Text('View profit report')),
            ],
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
                    valueColor: metrics.lowStockCount > 0
                        ? const Color(0xFFC62828)
                        : null,
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
          if (searching) ...[
            if (_searching)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_searchError)
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                  title: const Text('Search failed'),
                  subtitle: const Text(
                    'Something went wrong while searching. Tap to retry.',
                  ),
                  trailing: const Icon(Icons.refresh),
                  onTap: () {
                    final trimmed = _query.trim();
                    if (trimmed.isNotEmpty) _runSearch(trimmed);
                  },
                ),
              )
            else if (_productResults.isEmpty &&
                _customerResults.isEmpty &&
                _invoiceResults.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 36,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text('No matches', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Try a product name, phone number or invoice number.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              if (_productResults.isNotEmpty) ...[
                Text('Products', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._productResults.map(
                  (product) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(product.name),
                      subtitle: Text(
                        MoneyFormat.format(product.sellingPriceMinor),
                      ),
                      onTap: () => AppNavigator.toProductForm(
                        context,
                        productUuid: product.uuid,
                      ),
                    ),
                  ),
                ),
              ],
              if (_customerResults.isNotEmpty) ...[
                Text('Customers', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._customerResults.map(
                  (customer) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(customer.name),
                      subtitle: (customer.phone ?? '').isEmpty
                          ? null
                          : Text(customer.phone!),
                      trailing: MoneyText(amountMinor: customer.balanceMinor),
                      onTap: () => AppNavigator.toCustomerAccount(
                        context,
                        customerUuid: customer.uuid,
                      ),
                    ),
                  ),
                ),
              ],
              if (_invoiceResults.isNotEmpty) ...[
                Text('Invoices', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._invoiceResults.map(
                  (sale) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(sale.invoiceNumber),
                      subtitle: Text(sale.paymentMethod.toUpperCase()),
                      trailing: MoneyText(amountMinor: sale.totalMinor),
                      onTap: () => AppNavigator.toSaleDetail(
                        context,
                        saleUuid: sale.uuid,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
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
                color: valueColor,
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
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(height: 4),
              Text(title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
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
