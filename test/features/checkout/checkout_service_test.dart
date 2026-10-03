import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/utils/id_generator.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/payments/domain/payment.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/products/domain/product.dart';
import 'package:qubexcore_pos/features/sales/data/sale_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late ProductRepository products;
  late CustomerRepository customers;
  late SaleRepository sales;
  late CheckoutService checkout;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    products = ProductRepository(db);
    customers = CustomerRepository(db);
    sales = SaleRepository(db);
    checkout = CheckoutService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Product> createProduct({
    String name = 'Espresso',
    int price = 1200,
    int cost = 500,
    double stock = 10,
    bool trackStock = true,
    String? barcode,
    String? sku,
  }) async {
    final result = await products.create(
      name: name,
      sellingPriceMinor: price,
      costPriceMinor: cost,
      stockQuantity: stock,
      trackStock: trackStock,
      barcode: barcode,
      sku: sku,
    );
    expect(result.isSuccess, isTrue, reason: result.failureOrNull?.toString());
    return result.dataOrNull!;
  }

  CartItem cartFromProduct(Product product, {double quantity = 1}) {
    return CartItem.fromProduct(product, quantity: quantity);
  }

  test('completeSale writes sale, items, payment, stock, and movement',
      () async {
    final product = await createProduct(name: 'Latte', price: 450, stock: 8);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product, quantity: 2)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );

    expect(outcome.isSuccess, isTrue,
        reason: outcome.failureOrNull?.toString());
    final result = outcome.dataOrNull!;
    expect(result.sale.invoiceNumber, 'INV-000001');
    expect(result.sale.totalMinor, 900);
    expect(result.sale.amountPaidMinor, 900);
    expect(result.sale.changeMinor, 100);
    expect(result.sale.amountDueMinor, 0);
    expect(result.sale.paymentMethod, PaymentMethods.cash);
    expect(result.items, hasLength(1));
    expect(result.items.single.productName, 'Latte');
    expect(result.items.single.unitPriceMinor, 450);
    expect(result.items.single.unitCostMinor, 500);
    expect(result.items.single.quantity, 2);
    expect(result.items.single.lineTotalMinor, 900);
    expect(result.payment.receivedMinor, 1000);
    expect(result.payment.changeMinor, 100);

    final refreshed = await products.findByUuid(product.uuid);
    expect(refreshed!.stockQuantity, 6);

    final movements = await db.db.query(
      'stock_movements',
      where: 'product_id = ? AND movement_type = ?',
      whereArgs: [product.id, 'sale'],
    );
    expect(movements, hasLength(1));
    expect(movements.single['movement_type'], 'sale');
    expect(movements.single['quantity_change'], -2.0);
    expect(movements.single['quantity_after'], 6.0);
  });

  test('opening stock creates opening_stock movement on product create',
      () async {
    final product = await createProduct(name: 'Beans', stock: 12);
    final movements = await db.db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [product.id],
    );
    expect(movements, hasLength(1));
    expect(movements.single['movement_type'], 'opening_stock');
    expect(movements.single['quantity_change'], 12.0);
    expect(movements.single['quantity_after'], 12.0);
  });

  test('cash underpayment is blocked and writes nothing', () async {
    final product = await createProduct(price: 1000, stock: 5);
    final saleCountBefore = await sales.count();

    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 999,
      ),
    );

    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'insufficient_cash');
    expect(await sales.count(), saleCountBefore);
    final refreshed = await products.findByUuid(product.uuid);
    expect(refreshed!.stockQuantity, 5);
    final movements = await db.db.query('stock_movements');
    expect(movements, hasLength(1));
  });

  test('empty cart is blocked', () async {
    final outcome = await checkout.completeSale(
      const CheckoutRequest(
        items: [],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );
    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'empty_cart');
  });

  test('invalid quantity is blocked', () async {
    final product = await createProduct();
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product, quantity: 0)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );
    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'validation');
  });

  test('insufficient stock is blocked for tracked products', () async {
    final product = await createProduct(name: 'Rare', price: 100, stock: 1);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product, quantity: 5)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 500,
      ),
    );
    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'insufficient_stock');
    final refreshed = await products.findByUuid(product.uuid);
    expect(refreshed!.stockQuantity, 1);
  });

  test('untracked products skip stock decrement and movement', () async {
    final product = await createProduct(
      name: 'Service',
      price: 2000,
      stock: 0,
      trackStock: false,
    );
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.card,
      ),
    );
    expect(outcome.isSuccess, isTrue,
        reason: outcome.failureOrNull?.toString());
    final refreshed = await products.findByUuid(product.uuid);
    expect(refreshed!.stockQuantity, 0);
    final movements = await db.db.query('stock_movements');
    expect(movements, hasLength(0));
  });

  test('card sale records method and optional reference without cash fields',
      () async {
    final product = await createProduct(price: 1500, stock: 3);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.card,
        cardReference: 'AUTH-123',
      ),
    );
    expect(outcome.isSuccess, isTrue,
        reason: outcome.failureOrNull?.toString());
    final result = outcome.dataOrNull!;
    expect(result.sale.paymentMethod, PaymentMethods.card);
    expect(result.sale.amountPaidMinor, 1500);
    expect(result.sale.changeMinor, 0);
    expect(result.payment.reference, 'AUTH-123');
    expect(result.payment.receivedMinor, isNull);
  });

  test('credit sale requires customer and writes ledger + balance', () async {
    final product = await createProduct(price: 3000, stock: 4);
    final customerResult = await customers.create(
      name: 'Acme Retail',
      creditLimitMinor: 10000,
    );
    final customer = customerResult.dataOrNull!;

    final withoutCustomer = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.credit,
      ),
    );
    expect(withoutCustomer.isFailure, isTrue);
    expect(withoutCustomer.failureOrNull?.code, 'credit_requires_customer');

    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.credit,
        customerUuid: customer.uuid,
      ),
    );
    expect(outcome.isSuccess, isTrue,
        reason: outcome.failureOrNull?.toString());
    final result = outcome.dataOrNull!;
    expect(result.sale.amountDueMinor, 3000);
    expect(result.sale.amountPaidMinor, 0);
    expect(result.sale.customerId, customer.id);

    final refreshedCustomer = await customers.findByUuid(customer.uuid);
    expect(refreshedCustomer!.balanceMinor, 3000);

    final ledger = await db.db.query(
      'customer_ledger',
      where: 'customer_id = ?',
      whereArgs: [customer.id],
    );
    expect(ledger, hasLength(1));
    expect(ledger.single['entry_type'], 'debt_sale');
    expect(ledger.single['amount_minor'], 3000);
    expect(ledger.single['balance_after_minor'], 3000);
    expect(ledger.single['sale_uuid'], result.sale.uuid);
  });

  test('credit limit is enforced', () async {
    final product = await createProduct(price: 8000, stock: 2);
    final customer = (await customers.create(
      name: 'Limited',
      creditLimitMinor: 5000,
    ))
        .dataOrNull!;

    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.credit,
        customerUuid: customer.uuid,
      ),
    );
    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'credit_limit_exceeded');

    final refreshed = await customers.findByUuid(customer.uuid);
    expect(refreshed!.balanceMinor, 0);
    final ledger = await db.db.query('customer_ledger');
    expect(ledger, isEmpty);
    final refreshedProduct = await products.findByUuid(product.uuid);
    expect(refreshedProduct!.stockQuantity, 2);
  });

  test('credit without credit facility is blocked', () async {
    final product = await createProduct(price: 500, stock: 2);
    final customer = (await customers.create(name: 'Cash Only')).dataOrNull!;
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.credit,
        customerUuid: customer.uuid,
      ),
    );
    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'credit_limit_exceeded');
  });

  test('invoice numbers increment uniquely', () async {
    final product = await createProduct(price: 100, stock: 10);

    final first = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 100,
      ),
    );
    final second = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 100,
      ),
    );

    expect(first.dataOrNull!.sale.invoiceNumber, 'INV-000001');
    expect(second.dataOrNull!.sale.invoiceNumber, 'INV-000002');
  });

  test('historical snapshots survive later product changes', () async {
    final product = await createProduct(
      name: 'Original',
      price: 1000,
      cost: 400,
      stock: 5,
      barcode: '111',
      sku: 'SKU-1',
    );
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );
    expect(outcome.isSuccess, isTrue);

    final updated = product.copyWith(
      name: 'Renamed',
      sellingPriceMinor: 9999,
      costPriceMinor: 8888,
      barcode: '999',
      sku: 'SKU-9',
    );
    final updateResult = await products.update(updated);
    expect(updateResult.isSuccess, isTrue);

    final items = await sales.listItems(outcome.dataOrNull!.sale.id!);
    expect(items.single.productName, 'Original');
    expect(items.single.unitPriceMinor, 1000);
    expect(items.single.unitCostMinor, 400);
    expect(items.single.productBarcode, '111');
    expect(items.single.productSku, 'SKU-1');
    expect(items.single.lineTotalMinor, 1000);
  });

  test('failed stock update rolls back the entire sale', () async {
    final good = await createProduct(name: 'Good', price: 500, stock: 5);
    final soldOut = await createProduct(name: 'SoldOut', price: 500, stock: 0);
    final saleCountBefore = await sales.count();

    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [
          cartFromProduct(good),
          cartFromProduct(soldOut, quantity: 1),
        ],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );

    expect(outcome.isFailure, isTrue);
    expect(outcome.failureOrNull?.code, 'insufficient_stock');
    expect(await sales.count(), saleCountBefore);

    final goodRefreshed = await products.findByUuid(good.uuid);
    expect(goodRefreshed!.stockQuantity, 5);
    final soldOutRefreshed = await products.findByUuid(soldOut.uuid);
    expect(soldOutRefreshed!.stockQuantity, 0);

    final saleMovements = await db.db.query(
      'stock_movements',
      where: "movement_type = 'sale'",
    );
    expect(saleMovements, isEmpty);
  });

  test('duplicate saleUuid is idempotent and does not double-write', () async {
    final product = await createProduct(price: 250, stock: 4);
    final saleUuid = newBusinessId();

    final first = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 250,
        saleUuid: saleUuid,
      ),
    );
    expect(first.isSuccess, isTrue);

    final second = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 250,
        saleUuid: saleUuid,
      ),
    );
    expect(second.isSuccess, isTrue);
    expect(second.dataOrNull!.sale.uuid, saleUuid);
    expect(
      second.dataOrNull!.sale.invoiceNumber,
      first.dataOrNull!.sale.invoiceNumber,
    );

    final refreshed = await products.findByUuid(product.uuid);
    expect(refreshed!.stockQuantity, 3);
    expect(await sales.count(), 1);
  });

  test('change is recorded on sale and is not part of revenue', () async {
    final product = await createProduct(price: 750, stock: 2);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
      ),
    );
    expect(outcome.isSuccess, isTrue);
    final sale = outcome.dataOrNull!.sale;
    expect(sale.totalMinor, 750);
    expect(sale.amountPaidMinor, 750);
    expect(sale.changeMinor, 250);
    expect(sale.amountDueMinor, 0);
  });

  test('line discount reduces total and is snapshotted', () async {
    final product = await createProduct(price: 2000, stock: 3);
    final item = CartItem.fromProduct(product).copyWith(discountMinor: 250);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [item],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1750,
      ),
    );
    expect(outcome.isSuccess, isTrue,
        reason: outcome.failureOrNull?.toString());
    final result = outcome.dataOrNull!;
    expect(result.sale.subtotalMinor, 2000);
    expect(result.sale.discountMinor, 250);
    expect(result.sale.totalMinor, 1750);
    expect(result.items.single.discountMinor, 250);
  });

  test('sale repository can reload completed sales and items', () async {
    final product = await createProduct(name: 'Reload', price: 333, stock: 1);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 333,
      ),
    );
    final sale = outcome.dataOrNull!.sale;
    final loaded = await sales.findByUuid(sale.uuid);
    expect(loaded, isNotNull);
    expect(loaded!.invoiceNumber, sale.invoiceNumber);
    final items = await sales.listItems(loaded.id!);
    expect(items, hasLength(1));
    expect(items.single.productName, 'Reload');
  });

  test('completeSale records the staff uuid on sale, payment, and movement',
      () async {
    final product = await createProduct(name: 'Mocha', price: 800, stock: 5);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 1000,
        staffUuid: 'uuid-admin',
      ),
    );

    expect(outcome.isSuccess, isTrue);
    expect(outcome.dataOrNull!.sale.staffUuid, 'uuid-admin');

    final paymentRows = await db.db.query('payments');
    expect(paymentRows.single['staff_uuid'], 'uuid-admin');

    final movementRows = await db.db.query(
      'stock_movements',
      where: 'movement_type = ?',
      whereArgs: ['sale'],
    );
    expect(movementRows.single['staff_uuid'], 'uuid-admin');
  });

  test('credit sale records the staff uuid on the ledger entry', () async {
    final customer = await customers.create(
      name: 'Ledger Customer',
      creditLimitMinor: 500000,
    );
    final product = await createProduct(name: 'Juice', price: 700, stock: 4);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.credit,
        customerUuid: customer.dataOrNull!.uuid,
        staffUuid: 'uuid-cashier',
      ),
    );

    expect(outcome.isSuccess, isTrue);
    final ledger = await db.db.query('customer_ledger');
    expect(ledger, hasLength(1));
    expect(ledger.single['staff_uuid'], 'uuid-cashier');
    expect(ledger.single['entry_type'], 'debt_sale');
  });

  test('sale currency defaults to LKR', () async {
    final product = await createProduct(name: 'Tea', price: 300, stock: 5);
    final outcome = await checkout.completeSale(
      CheckoutRequest(
        items: [cartFromProduct(product)],
        paymentMethod: PaymentMethods.cash,
        cashReceivedMinor: 300,
      ),
    );

    expect(outcome.isSuccess, isTrue);
    expect(outcome.dataOrNull!.items.single.currency, 'LKR');
    final stored = await db.db.query('sale_items');
    expect(stored.single['currency'], 'LKR');
  });
}
