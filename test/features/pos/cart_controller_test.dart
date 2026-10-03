import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_controller.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/products/domain/product.dart';

CartItem _item({
  required String uuid,
  required String name,
  int price = 1000,
  int cost = 400,
  double quantity = 1,
  int discount = 0,
  bool trackStock = true,
}) {
  return CartItem(
    productUuid: uuid,
    productName: name,
    unitPriceMinor: price,
    unitCostMinor: cost,
    quantity: quantity,
    discountMinor: discount,
    trackStock: trackStock,
  );
}

Product _product({
  required String uuid,
  required String name,
  int price = 2500,
  int cost = 900,
  double stock = 10,
  bool trackStock = true,
}) {
  return Product(
    uuid: uuid,
    name: name,
    sellingPriceMinor: price,
    costPriceMinor: cost,
    stockQuantity: stock,
    trackStock: trackStock,
    createdAt: '2026-01-01T00:00:00.000Z',
    updatedAt: '2026-01-01T00:00:00.000Z',
  );
}

void main() {
  test('cart item computes line gross and line total in minor units', () {
    final item = _item(uuid: 'p1', name: 'A', price: 2500, quantity: 3);
    expect(item.lineGrossMinor, 7500);
    expect(item.lineTotalMinor, 7500);

    final discounted = _item(
      uuid: 'p1',
      name: 'A',
      price: 2500,
      quantity: 3,
      discount: 500,
    );
    expect(discounted.lineTotalMinor, 7000);

    final fractional = _item(uuid: 'p1', name: 'A', price: 199, quantity: 2.5);
    expect(fractional.lineGrossMinor, 498);
  });

  test('cart item from product snapshots price and cost', () {
    final product =
        _product(uuid: 'p1', name: 'Coffee', price: 1250, cost: 700);
    final item = CartItem.fromProduct(product, quantity: 2);
    expect(item.productUuid, 'p1');
    expect(item.productName, 'Coffee');
    expect(item.unitPriceMinor, 1250);
    expect(item.unitCostMinor, 700);
    expect(item.quantity, 2);
    expect(item.lineTotalMinor, 2500);
    expect(item.trackStock, isTrue);
    expect(item.currency, 'LKR');
  });

  test('cart totals accumulate subtotal, discount, tax zero, and count', () {
    final cart = CartController();
    cart.addItem(_item(uuid: 'a', name: 'A', price: 1000, quantity: 2));
    cart.addItem(
        _item(uuid: 'b', name: 'B', price: 500, quantity: 1, discount: 100));

    expect(cart.itemCount, 3);
    expect(cart.subtotalMinor, 2500);
    expect(cart.discountMinor, 100);
    expect(cart.taxMinor, 0);
    expect(cart.totalMinor, 2400);
  });

  test('adding the same product merges quantities', () {
    final cart = CartController();
    cart.addItem(_item(uuid: 'a', name: 'A', price: 1000, quantity: 1));
    cart.addItem(_item(uuid: 'a', name: 'A', price: 1000, quantity: 2));

    expect(cart.items.length, 1);
    expect(cart.items.single.quantity, 3);
    expect(cart.totalMinor, 3000);
  });

  test('setQuantity removes line when quantity reaches zero', () {
    final cart = CartController();
    cart.addItem(_item(uuid: 'a', name: 'A'));
    cart.addItem(_item(uuid: 'b', name: 'B', price: 500));

    cart.setQuantity('a', 0);
    expect(cart.items.length, 1);
    expect(cart.totalMinor, 500);

    cart.setQuantity('b', 4);
    expect(cart.totalMinor, 2000);
  });

  test('increment and decrement adjust quantities and clear empties', () {
    final cart = CartController();
    cart.addItem(_item(uuid: 'a', name: 'A', price: 100));
    cart.increment('a');
    expect(cart.items.single.quantity, 2);
    cart.decrement('a');
    expect(cart.items.single.quantity, 1);
    cart.decrement('a');
    expect(cart.isEmpty, isTrue);
  });

  test('clear empties the cart', () {
    final cart = CartController();
    cart.addItem(_item(uuid: 'a', name: 'A'));
    cart.addItem(_item(uuid: 'b', name: 'B'));
    cart.clear();
    expect(cart.isEmpty, isTrue);
    expect(cart.totalMinor, 0);
    expect(cart.itemCount, 0);
  });

  group('stock caps', () {
    test('addItem caps a new line at the available stock', () {
      final cart = CartController();
      final result = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 3),
        quantity: 5,
      ));
      expect(result, CartChangeResult.capped);
      expect(cart.items.single.quantity, 3);
    });

    test('addItem refuses an out-of-stock product', () {
      final cart = CartController();
      final result = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 0),
      ));
      expect(result, CartChangeResult.outOfStock);
      expect(cart.isEmpty, isTrue);
    });

    test('adding past the cap reports atLimit without changing quantity', () {
      final cart = CartController();
      cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 2),
      ));
      final full = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 2),
      ));
      expect(full, CartChangeResult.ok, reason: 'second unit fills the cap');
      final result = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 2),
      ));
      expect(result, CartChangeResult.atLimit);
      expect(cart.items.single.quantity, 2);
    });

    test('adding the same product again keeps the line discount', () {
      final cart = CartController();
      cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 10),
      ));
      cart.setDiscount('p1', 150);
      final result = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 10),
      ));
      expect(result, CartChangeResult.ok);
      expect(cart.items.single.quantity, 2);
      expect(cart.items.single.discountMinor, 150);
    });

    test('increment stops at the stock limit', () {
      final cart = CartController();
      cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 2),
      ));
      expect(cart.increment('p1'), CartChangeResult.ok);
      expect(cart.items.single.quantity, 2);
      expect(cart.increment('p1'), CartChangeResult.atLimit);
      expect(cart.items.single.quantity, 2);
    });

    test('setQuantity clamps to the stock level', () {
      final cart = CartController();
      cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Beans', stock: 4),
      ));
      expect(cart.setQuantity('p1', 99), CartChangeResult.capped);
      expect(cart.items.single.quantity, 4);
      expect(cart.setQuantity('p1', 0), CartChangeResult.ok);
      expect(cart.isEmpty, isTrue);
    });

    test('untracked products are never capped', () {
      final cart = CartController();
      final result = cart.addItem(CartItem.fromProduct(
        _product(uuid: 'p1', name: 'Delivery fee', stock: 0, trackStock: false),
        quantity: 50,
      ));
      expect(result, CartChangeResult.ok);
      expect(cart.items.single.quantity, 50);
    });
  });

  group('discounts and notes', () {
    test('setDiscount clamps to zero and to the line total', () {
      final cart = CartController();
      cart.addItem(_item(uuid: 'p1', name: 'Beans', price: 500, quantity: 2));

      cart.setDiscount('p1', -100);
      expect(cart.discountMinor, 0);

      cart.setDiscount('p1', 99999);
      expect(cart.discountMinor, 1000, reason: 'line gross is 1000');
      expect(cart.totalMinor, 0);
    });

    test('note is stored and cleared with the cart', () {
      final cart = CartController();
      cart.note = 'Pack separately';
      expect(cart.note, 'Pack separately');
      cart.clear();
      expect(cart.note, isEmpty);
    });
  });
}
