import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/dashboard/data/dashboard_repository.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/payments/domain/payment.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late DashboardRepository dashboard;
  late ProductRepository products;
  late CustomerRepository customers;
  late CheckoutService checkout;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    dashboard = DashboardRepository(db);
    products = ProductRepository(db);
    customers = CustomerRepository(db);
    checkout = CheckoutService(db);
    await SettingsRepository(db).ensureSeededDefaults();
  });

  tearDown(() async {
    await db.close();
  });

  test('metrics start at zero', () async {
    final metrics = await dashboard.metrics();
    expect(metrics.todaySalesTotalMinor, 0);
    expect(metrics.todayTransactionCount, 0);
    expect(metrics.outstandingCreditMinor, 0);
    expect(metrics.lowStockCount, 0);
  });

  test('metrics count today sales, credit balances, and low stock', () async {
    final product = (await products.create(
      name: 'Espresso',
      sellingPriceMinor: 1200,
      stockQuantity: 3,
      reorderLevel: 5,
    ))
        .dataOrNull!;
    await checkout.completeSale(
      CheckoutRequest(
        items: [CartItem.fromProduct(product, quantity: 2)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 5000,
      ),
    );

    final metrics = await dashboard.metrics();
    expect(metrics.todaySalesTotalMinor, 2400);
    expect(metrics.todayTransactionCount, 1);
    // stock 1 <= reorder 5 → low stock.
    expect(metrics.lowStockCount, 1);

    final customer = (await customers.create(
      name: 'Nimal',
      creditLimitMinor: 50000,
    ))
        .dataOrNull!;
    await checkout.completeSale(
      CheckoutRequest(
        items: [CartItem.fromProduct(product, quantity: 1)],
        paymentMethod: PaymentMethods.credit,
        customerUuid: customer.uuid,
      ),
    );
    final afterCredit = await dashboard.metrics();
    expect(afterCredit.todayTransactionCount, 2);
    expect(afterCredit.outstandingCreditMinor, greaterThan(0));
    expect(
      afterCredit.outstandingCreditMinor,
      afterCredit.todaySalesTotalMinor - 2400,
    );
  });

  test('outstanding credit excludes archived customers', () async {
    final customer = (await customers.create(
      name: 'Old Account',
      creditLimitMinor: 10000,
    ))
        .dataOrNull!;
    await db.db.update(
      'customers',
      {'balance_minor': 7500, 'is_archived': 1},
      where: 'uuid = ?',
      whereArgs: [customer.uuid],
    );
    final metrics = await dashboard.metrics();
    expect(metrics.outstandingCreditMinor, 0);
  });
}
