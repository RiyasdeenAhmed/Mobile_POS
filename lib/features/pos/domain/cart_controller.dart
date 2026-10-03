import 'package:flutter/foundation.dart';

import 'cart_item.dart';

class CartTotals {
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final int itemCount;

  const CartTotals({
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.itemCount,
  });
}

class CartController extends ChangeNotifier {
  final List<CartItem> _items = <CartItem>[];

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  int get lineCount => _items.length;

  CartTotals get totals {
    var subtotal = 0;
    var discount = 0;
    var count = 0;
    for (final item in _items) {
      subtotal += item.lineGrossMinor;
      discount += item.discountMinor;
      count += item.quantity.round();
    }
    const tax = 0;
    return CartTotals(
      subtotalMinor: subtotal,
      discountMinor: discount,
      taxMinor: tax,
      totalMinor: subtotal - discount + tax,
      itemCount: count,
    );
  }

  int get subtotalMinor => totals.subtotalMinor;

  int get discountMinor => totals.discountMinor;

  int get taxMinor => totals.taxMinor;

  int get totalMinor => totals.totalMinor;

  int get itemCount => totals.itemCount;

  void addItem(CartItem item) {
    final index =
        _items.indexWhere((element) => element.productUuid == item.productUuid);
    if (index >= 0) {
      final existing = _items[index];
      _items[index] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        discountMinor: item.discountMinor,
      );
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void setQuantity(String productUuid, double quantity) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
  }

  void increment(String productUuid) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return;
    final existing = _items[index];
    _items[index] = existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
  }

  void decrement(String productUuid) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return;
    final existing = _items[index];
    final next = existing.quantity - 1;
    if (next <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = existing.copyWith(quantity: next);
    }
    notifyListeners();
  }

  void removeItem(String productUuid) {
    _items.removeWhere((element) => element.productUuid == productUuid);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
