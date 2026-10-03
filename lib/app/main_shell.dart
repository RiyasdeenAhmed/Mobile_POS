import 'package:flutter/material.dart';

import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/dashboard/presentation/more_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import 'routes.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<String> _titles = [
    'Dashboard',
    'Sales',
    'Products',
    'Customers',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_index) {
      0 => const DashboardScreen(),
      1 => const SalesScreen(),
      2 => const ProductsScreen(),
      3 => const CustomersScreen(),
      _ => const MoreScreen(),
    };

    // Tabs that render their own chrome (app bar and FAB) stay in charge of
    // their primary action: Add product on Products, Add customer on
    // Customers. The shell keeps New Sale reachable from every other tab.
    final screenOwnsChrome = _index == 2 || _index == 3;

    return Scaffold(
      appBar: screenOwnsChrome
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                IconButton(
                  tooltip: 'New Sale',
                  icon: const Icon(Icons.point_of_sale),
                  onPressed: () => AppNavigator.toNewSale(context),
                ),
              ],
            ),
      body: body,
      floatingActionButton: (screenOwnsChrome || _index == 4)
          ? null
          : FloatingActionButton.extended(
              onPressed: () => AppNavigator.toNewSale(context),
              icon: const Icon(Icons.add),
              label: const Text('New Sale'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Sales',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Customers',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz_outlined),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
