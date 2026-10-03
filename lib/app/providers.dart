import 'package:nested/nested.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/database/settings_repository.dart';
import '../../core/security/pin_hasher.dart';
import '../../features/categories/data/category_repository.dart';
import '../../features/checkout/data/checkout_service.dart';
import '../../features/customers/data/customer_ledger_repository.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/customers/data/repayment_service.dart';
import '../../features/pos/domain/cart_controller.dart';
import '../../features/inventory/data/stock_movement_repository.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/receipts/data/mock_printer.dart';
import '../../features/receipts/data/printer_service.dart';
import '../../features/receipts/data/receipt_print_service.dart';
import '../../features/sales/data/sale_repository.dart';
import '../../features/staff/application/staff_session.dart';
import '../../features/staff/data/staff_repository.dart';

List<SingleChildWidget> buildAppProviders(
  AppDatabase database, {
  int pinIterations = defaultIterations,
}) {
  return <SingleChildWidget>[
    Provider<AppDatabase>.value(value: database),
    ProxyProvider<AppDatabase, SettingsRepository>(
      update: (_, db, __) => SettingsRepository(db),
    ),
    ProxyProvider<AppDatabase, ProductRepository>(
      update: (_, db, __) => ProductRepository(db),
    ),
    ProxyProvider<AppDatabase, CategoryRepository>(
      update: (_, db, __) => CategoryRepository(db),
    ),
    ProxyProvider<AppDatabase, StockMovementRepository>(
      update: (_, db, __) => StockMovementRepository(db),
    ),
    ProxyProvider<AppDatabase, CustomerRepository>(
      update: (_, db, __) => CustomerRepository(db),
    ),
    ProxyProvider<AppDatabase, CustomerLedgerRepository>(
      update: (_, db, __) => CustomerLedgerRepository(db),
    ),
    ProxyProvider<AppDatabase, RepaymentService>(
      update: (_, db, __) => RepaymentService(db),
    ),
    ProxyProvider<AppDatabase, SaleRepository>(
      update: (_, db, __) => SaleRepository(db),
    ),
    ProxyProvider<AppDatabase, StaffRepository>(
      update: (_, db, __) => StaffRepository(db, pinIterations: pinIterations),
    ),
    ProxyProvider<AppDatabase, CheckoutService>(
      update: (_, db, __) => CheckoutService(db),
    ),
    Provider<PrinterService>(
      create: (_) => MockPrinter(),
    ),
    Provider<ReceiptPrintService>(
      create: (context) => ReceiptPrintService(
        printer: context.read<PrinterService>(),
        settings: context.read<SettingsRepository>(),
        customers: context.read<CustomerRepository>(),
      ),
    ),
    ChangeNotifierProvider<CartController>(
      create: (_) => CartController(),
    ),
    ChangeNotifierProxyProvider<StaffRepository, StaffSession>(
      create: (_) => StaffSession(),
      update: (_, repository, session) {
        if (session == null) {
          return StaffSession()..attach(repository);
        }
        session.attach(repository);
        return session;
      },
    ),
  ];
}
