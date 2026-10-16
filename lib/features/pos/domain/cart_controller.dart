import '../../../core/utils/tax_calculator.dart';
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

/// Result of an attempted cart change, so the UI can explain what happened.
enum CartChangeResult {
  /// The cart now holds the requested quantity.
  ok,

  /// The request exceeded available stock; the cart was capped.
  capped,

  /// The line is already at the stock limit; nothing changed.
  atLimit,

  /// The product has no stock left; nothing was added.
  outOfStock,
}

class CartController extends ChangeNotifier {
  final List<CartItem> _items = <CartItem>[];
  String _note = '';
  int _taxRateBps = 0;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setTaxRate(int rate) {
    if (_disposed || _taxRateBps == rate) return;
    _taxRateBps = rate;
    notifyListeners();
  }

  List<CartItem> get items => List<CartItem>.unmodifiable(_items);

  String get note => _note;

  set note(String value) {
    if (_note == value) return;
    _note = value;
    notifyListeners();
  }

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
    final tax = TaxCalculator.taxMinor(subtotal - discount, _taxRateBps);
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

  CartChangeResult addItem(CartItem item) {
    final cap = item.maxQuantity;
    final index =
        _items.indexWhere((element) => element.productUuid == item.productUuid);

    if (index >= 0) {
      final existing = _items[index];
      final existingCap = existing.maxQuantity;
      if (existing.quantity >= existingCap) {
        return CartChangeResult.atLimit;
      }
      final requested = existing.quantity + item.quantity;
      final next = requested > existingCap ? existingCap : requested;
      _items[index] = existing.copyWith(
        quantity: next,
        // Adding the same product again never wipes the line discount.
        discountMinor: existing.discountMinor,
      );
      notifyListeners();
      return next < requested ? CartChangeResult.capped : CartChangeResult.ok;
    }

    if (item.trackStock && item.quantity > cap) {
      if (cap <= 0) return CartChangeResult.outOfStock;
      _items.add(item.copyWith(quantity: cap));
      notifyListeners();
      return CartChangeResult.capped;
    }
    _items.add(item);
    notifyListeners();
    return CartChangeResult.ok;
  }

  CartChangeResult setQuantity(String productUuid, double quantity) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return CartChangeResult.ok;
    if (quantity <= 0) {
      _items.removeAt(index);
      notifyListeners();
      return CartChangeResult.ok;
    }
    final existing = _items[index];
    final cap = existing.maxQuantity;
    final clamped = quantity > cap ? cap : quantity;
    if (clamped == existing.quantity) {
      return quantity > cap ? CartChangeResult.capped : CartChangeResult.ok;
    }
    _items[index] = existing.copyWith(quantity: clamped);
    notifyListeners();
    return clamped < quantity ? CartChangeResult.capped : CartChangeResult.ok;
  }

  CartChangeResult increment(String productUuid) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return CartChangeResult.ok;
    final existing = _items[index];
    final cap = existing.maxQuantity;
    if (existing.quantity >= cap) return CartChangeResult.atLimit;
    final next = existing.quantity + 1;
    final capped = next > cap;
    _items[index] = existing.copyWith(quantity: capped ? cap : next);
    notifyListeners();
    return capped ? CartChangeResult.capped : CartChangeResult.ok;
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

  CartChangeResult setDiscount(String productUuid, int discountMinor) {
    final index =
        _items.indexWhere((element) => element.productUuid == productUuid);
    if (index < 0) return CartChangeResult.ok;
    final existing = _items[index];
    final lineTotal = existing.lineGrossMinor;
    var discount = discountMinor;
    if (discount < 0) discount = 0;
    if (discount > lineTotal) discount = lineTotal;
    if (discount == existing.discountMinor) return CartChangeResult.ok;
    _items[index] = existing.copyWith(discountMinor: discount);
    notifyListeners();
    return CartChangeResult.ok;
  }

  void clear() {
    _items.clear();
    _note = '';
    notifyListeners();
  }
}
