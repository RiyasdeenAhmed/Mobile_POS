import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/payments/domain/payment.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/sales/data/sale_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SaleRepository sales;
  late ProductRepository products;
  late CustomerRepository customers;
  late CheckoutService checkout;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sales = SaleRepository(db);
    products = ProductRepository(db);
    customers = CustomerRepository(db);
    checkout = CheckoutService(db);
    await SettingsRepository(db).ensureSeededDefaults();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> saleOf({
    String paymentMethod = PaymentMethods.cash,
    String? customerUuid,
  }) async {
    final product = (await products.create(
      name: 'Espresso',
      sellingPriceMinor: 1200,
      stockQuantity: 50,
    ))
        .dataOrNull!;
    final result = await checkout.completeSale(
      CheckoutRequest(
        items: [CartItem.fromProduct(product)],
        paymentMethod: paymentMethod,
        cashReceivedMinor: 5000,
        customerUuid: customerUuid,
      ),
    );
    return result.dataOrNull!.sale.uuid;
  }

  Future<void> backdate(String saleUuid, String saleAt) async {
    await db.db.update(
      'sales',
      {'sale_at': saleAt},
      where: 'uuid = ?',
      whereArgs: [saleUuid],
    );
  }

  test('list filters by payment method', () async {
    await saleOf(paymentMethod: PaymentMethods.cash);
    final cardUuid = await saleOf(paymentMethod: PaymentMethods.card);

    final cashOnly = await sales.list(paymentMethod: PaymentMethods.cash);
    expect(cashOnly, hasLength(1));
    expect(cashOnly.single.paymentMethod, 'cash');

    final cardOnly = await sales.list(paymentMethod: PaymentMethods.card);
    expect(cardOnly, hasLength(1));
    expect(cardOnly.single.uuid, cardUuid);

    expect(await sales.list(), hasLength(2));
  });

  test('list filters by date range', () async {
    final todayUuid = await saleOf();
    final yesterdayUuid = await saleOf();
    await backdate(todayUuid, '2020-06-15T12:00:00.000Z');
    await backdate(yesterdayUuid, '2020-06-14T12:00:00.000Z');

    final todayStart = DateTime.utc(2020, 6, 15);
    final todayEnd = DateTime.utc(2020, 6, 16);
    final todaySales = await sales.list(from: todayStart, to: todayEnd);
    expect(todaySales, hasLength(1));
    expect(todaySales.single.uuid, todayUuid);

    final recent = await sales.list(
      from: DateTime.utc(2020, 6, 14),
      to: todayEnd,
    );
    expect(recent, hasLength(2));
    expect(
      recent.map((sale) => sale.uuid),
      containsAll(<String>[todayUuid, yesterdayUuid]),
    );

    final none = await sales.list(
      from: DateTime.utc(2030, 1, 1),
      to: DateTime.utc(2030, 1, 2),
    );
    expect(none, isEmpty);
  });

  test('list filters by customer', () async {
    final customer =
        (await customers.create(name: 'Nimal', creditLimitMinor: 50000))
            .dataOrNull!;
    final creditUuid = await saleOf(
      paymentMethod: PaymentMethods.credit,
      customerUuid: customer.uuid,
    );
    await saleOf();

    final customerSales = await sales.list(customerId: customer.id);
    expect(customerSales, hasLength(1));
    expect(customerSales.single.uuid, creditUuid);
  });
}
