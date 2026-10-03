import '../../../core/utils/time_utils.dart';

class Product {
  final int? id;
  final String uuid;
  final String? sku;
  final String? barcode;
  final String name;
  final int? categoryId;
  final int costPriceMinor;
  final int sellingPriceMinor;
  final String currency;
  final double stockQuantity;
  final double reorderLevel;
  final bool trackStock;
  final bool isActive;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  const Product({
    this.id,
    required this.uuid,
    this.sku,
    this.barcode,
    required this.name,
    this.categoryId,
    this.costPriceMinor = 0,
    this.sellingPriceMinor = 0,
    this.currency = 'USD',
    this.stockQuantity = 0,
    this.reorderLevel = 0,
    this.trackStock = true,
    this.isActive = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get createdDateTime => tryParseIso(createdAt);
  DateTime? get updatedDateTime => tryParseIso(updatedAt);

  Product copyWith({
    int? id,
    String? uuid,
    String? sku,
    String? barcode,
    String? name,
    int? categoryId,
    int? costPriceMinor,
    int? sellingPriceMinor,
    String? currency,
    double? stockQuantity,
    double? reorderLevel,
    bool? trackStock,
    bool? isActive,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      costPriceMinor: costPriceMinor ?? this.costPriceMinor,
      sellingPriceMinor: sellingPriceMinor ?? this.sellingPriceMinor,
      currency: currency ?? this.currency,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      trackStock: trackStock ?? this.trackStock,
      isActive: isActive ?? this.isActive,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'sku': sku,
      'barcode': barcode,
      'name': name,
      'category_id': categoryId,
      'cost_price_minor': costPriceMinor,
      'selling_price_minor': sellingPriceMinor,
      'currency': currency,
      'stock_quantity': stockQuantity,
      'reorder_level': reorderLevel,
      'track_stock': trackStock ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int?,
      costPriceMinor: (map['cost_price_minor'] as int?) ?? 0,
      sellingPriceMinor: (map['selling_price_minor'] as int?) ?? 0,
      currency: (map['currency'] as String?) ?? 'USD',
      stockQuantity: (map['stock_quantity'] as num?)?.toDouble() ?? 0,
      reorderLevel: (map['reorder_level'] as num?)?.toDouble() ?? 0,
      trackStock: ((map['track_stock'] as int?) ?? 1) == 1,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
