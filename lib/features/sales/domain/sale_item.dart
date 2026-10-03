import '../../../core/utils/time_utils.dart';

class SaleItem {
  final int? id;
  final String uuid;
  final int saleId;
  final int productId;
  final String productUuid;
  final String productName;
  final String? productSku;
  final String? productBarcode;
  final double quantity;
  final int unitPriceMinor;
  final int unitCostMinor;
  final int discountMinor;
  final int lineTotalMinor;
  final String currency;
  final String createdAt;

  const SaleItem({
    this.id,
    required this.uuid,
    required this.saleId,
    required this.productId,
    required this.productUuid,
    required this.productName,
    this.productSku,
    this.productBarcode,
    required this.quantity,
    required this.unitPriceMinor,
    this.unitCostMinor = 0,
    this.discountMinor = 0,
    required this.lineTotalMinor,
    this.currency = 'LKR',
    required this.createdAt,
  });

  DateTime? get createdDateTime => tryParseIso(createdAt);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'sale_id': saleId,
      'product_id': productId,
      'product_uuid': productUuid,
      'product_name': productName,
      'product_sku': productSku,
      'product_barcode': productBarcode,
      'quantity': quantity,
      'unit_price_minor': unitPriceMinor,
      'unit_cost_minor': unitCostMinor,
      'discount_minor': discountMinor,
      'line_total_minor': lineTotalMinor,
      'currency': currency,
      'created_at': createdAt,
    };
  }

  factory SaleItem.fromMap(Map<String, Object?> map) {
    return SaleItem(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productUuid: map['product_uuid'] as String,
      productName: map['product_name'] as String,
      productSku: map['product_sku'] as String?,
      productBarcode: map['product_barcode'] as String?,
      quantity: (map['quantity'] as num).toDouble(),
      unitPriceMinor: (map['unit_price_minor'] as num).toInt(),
      unitCostMinor: (map['unit_cost_minor'] as num?)?.toInt() ?? 0,
      discountMinor: (map['discount_minor'] as num?)?.toInt() ?? 0,
      lineTotalMinor: (map['line_total_minor'] as num).toInt(),
      currency: (map['currency'] as String?) ?? 'LKR',
      createdAt: map['created_at'] as String,
    );
  }
}
