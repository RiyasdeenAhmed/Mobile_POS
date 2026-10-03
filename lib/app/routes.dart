import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/customers/presentation/customer_account_screen.dart';
import '../features/customers/presentation/customer_form_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/more_screen.dart';
import '../features/inventory/presentation/inventory_screen.dart';
import '../features/pos/presentation/cart_screen.dart';
import '../features/pos/presentation/new_sale_screen.dart';
import '../features/products/presentation/product_form_screen.dart';
import '../features/products/presentation/products_screen.dart';
import '../features/receipts/presentation/receipt_screen.dart';
import '../features/sales/presentation/sale_detail_screen.dart';
import '../features/sales/presentation/sales_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'main_shell.dart';

class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String mainShell = '/main-shell';
  static const String dashboard = '/dashboard';
  static const String newSale = '/pos/new-sale';
  static const String cart = '/pos/cart';
  static const String checkout = '/checkout';
  static const String receipt = '/receipt';
  static const String sales = '/sales';
  static const String saleDetail = '/sales/detail';
  static const String products = '/products';
  static const String productForm = '/products/form';
  static const String categories = '/categories';
  static const String customers = '/customers';
  static const String customerAccount = '/customers/account';
  static const String customerForm = '/customers/form';
  static const String inventory = '/inventory';
  static const String more = '/more';
  static const String settings = '/settings';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginScreen(),
        );
      case AppRoutes.mainShell:
      case AppRoutes.dashboard:
      case AppRoutes.splash:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MainShell(),
        );
      case AppRoutes.newSale:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const NewSaleScreen(),
        );
      case AppRoutes.cart:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CartScreen(),
        );
      case AppRoutes.checkout:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CheckoutScreen(),
        );
      case AppRoutes.receipt:
        final saleUuid =
            settings.arguments is String ? settings.arguments! as String : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => ReceiptScreen(saleUuid: saleUuid),
        );
      case AppRoutes.sales:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SalesScreen(),
        );
      case AppRoutes.saleDetail:
        final saleUuid =
            settings.arguments is String ? settings.arguments! as String : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => SaleDetailScreen(saleUuid: saleUuid),
        );
      case AppRoutes.products:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProductsScreen(),
        );
      case AppRoutes.productForm:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const ProductFormScreen(),
        );
      case AppRoutes.categories:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CategoriesScreen(),
        );
      case AppRoutes.customers:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomersScreen(),
        );
      case AppRoutes.customerAccount:
        final customerUuid =
            settings.arguments is String ? settings.arguments! as String : null;
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => CustomerAccountScreen(customerUuid: customerUuid),
        );
      case AppRoutes.customerForm:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CustomerFormScreen(),
        );
      case AppRoutes.inventory:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const InventoryScreen(),
        );
      case AppRoutes.more:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MoreScreen(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsScreen(),
        );
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MainShell(),
        );
    }
  }
}

class AppNavigator {
  static Future<T?> pushNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  }

  static Future<T?> replaceNamed<T>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushReplacementNamed<T, void>(
      routeName,
      arguments: arguments,
    );
  }

  static Future<T?> toLogin<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.login);

  static Future<T?> toMainShell<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.mainShell);

  static Future<T?> toDashboard<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.dashboard);

  static Future<T?> toNewSale<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.newSale);

  static Future<T?> toCart<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.cart);

  static Future<T?> toCheckout<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.checkout);

  static Future<T?> toReceipt<T>(BuildContext context, {String? saleUuid}) =>
      pushNamed<T>(context, AppRoutes.receipt, arguments: saleUuid);

  static Future<T?> toSales<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.sales);

  static Future<T?> toSaleDetail<T>(BuildContext context, {String? saleUuid}) =>
      pushNamed<T>(context, AppRoutes.saleDetail, arguments: saleUuid);

  static Future<T?> toProducts<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.products);

  static Future<T?> toProductForm<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.productForm);

  static Future<T?> toCategories<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.categories);

  static Future<T?> toCustomers<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.customers);

  static Future<T?> toCustomerAccount<T>(
    BuildContext context, {
    String? customerUuid,
  }) =>
      pushNamed<T>(
        context,
        AppRoutes.customerAccount,
        arguments: customerUuid,
      );

  static Future<T?> toCustomerForm<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.customerForm);

  static Future<T?> toInventory<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.inventory);

  static Future<T?> toMore<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.more);

  static Future<T?> toSettings<T>(BuildContext context) =>
      pushNamed<T>(context, AppRoutes.settings);
}
