import '../../products/domain/product.dart';

class CartItem {
  final String productUuid;
  final String productName;
  final String? productSku;
  final String? productBarcode;
  final int unitPriceMinor;
  final int unitCostMinor;
  final double quantity;
  final int discountMinor;
  final bool trackStock;
  final String currency;

  const CartItem({
    required this.productUuid,
    required this.productName,
    this.productSku,
    this.productBarcode,
    required this.unitPriceMinor,
    this.unitCostMinor = 0,
    this.quantity = 1,
    this.discountMinor = 0,
    this.trackStock = true,
    this.currency = 'USD',
  });

  factory CartItem.fromProduct(
    Product product, {
    double quantity = 1,
    int discountMinor = 0,
  }) {
    return CartItem(
      productUuid: product.uuid,
      productName: product.name,
      productSku: product.sku,
      productBarcode: product.barcode,
      unitPriceMinor: product.sellingPriceMinor,
      unitCostMinor: product.costPriceMinor,
      quantity: quantity,
      discountMinor: discountMinor,
      trackStock: product.trackStock,
      currency: product.currency,
    );
  }

  int get lineGrossMinor => (unitPriceMinor * quantity).round();

  int get lineTotalMinor => lineGrossMinor - discountMinor;

  CartItem copyWith({
    String? productUuid,
    String? productName,
    String? productSku,
    String? productBarcode,
    int? unitPriceMinor,
    int? unitCostMinor,
    double? quantity,
    int? discountMinor,
    bool? trackStock,
    String? currency,
  }) {
    return CartItem(
      productUuid: productUuid ?? this.productUuid,
      productName: productName ?? this.productName,
      productSku: productSku ?? this.productSku,
      productBarcode: productBarcode ?? this.productBarcode,
      unitPriceMinor: unitPriceMinor ?? this.unitPriceMinor,
      unitCostMinor: unitCostMinor ?? this.unitCostMinor,
      quantity: quantity ?? this.quantity,
      discountMinor: discountMinor ?? this.discountMinor,
      trackStock: trackStock ?? this.trackStock,
      currency: currency ?? this.currency,
    );
  }
}
