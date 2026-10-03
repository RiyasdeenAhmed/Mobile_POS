import '../../../core/utils/time_utils.dart';

class StockMovement {
  final int? id;
  final String uuid;
  final int productId;
  final String movementType;
  final double quantityChange;
  final double quantityAfter;
  final String? referenceType;
  final int? referenceId;
  final String? note;
  final String? staffUuid;
  final String createdAt;

  /// Product name resolved by list queries; null when loaded bare.
  final String? productName;

  const StockMovement({
    this.id,
    required this.uuid,
    required this.productId,
    required this.movementType,
    required this.quantityChange,
    required this.quantityAfter,
    this.referenceType,
    this.referenceId,
    this.note,
    this.staffUuid,
    required this.createdAt,
    this.productName,
  });

  bool get isIncrease => quantityChange > 0;
  bool get isDecrease => quantityChange < 0;
  DateTime? get createdDateTime => tryParseIso(createdAt);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'product_id': productId,
      'movement_type': movementType,
      'quantity_change': quantityChange,
      'quantity_after': quantityAfter,
      'reference_type': referenceType,
      'reference_id': referenceId,
      'note': note,
      'staff_uuid': staffUuid,
      'created_at': createdAt,
    };
  }

  factory StockMovement.fromMap(Map<String, Object?> map) {
    return StockMovement(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      productId: map['product_id'] as int,
      movementType: map['movement_type'] as String,
      quantityChange: (map['quantity_change'] as num).toDouble(),
      quantityAfter: (map['quantity_after'] as num).toDouble(),
      referenceType: map['reference_type'] as String?,
      referenceId: map['reference_id'] as int?,
      note: map['note'] as String?,
      staffUuid: map['staff_uuid'] as String?,
      createdAt: map['created_at'] as String,
      productName: map['product_name'] as String?,
    );
  }
}
