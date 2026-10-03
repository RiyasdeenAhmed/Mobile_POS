class SaleReturn {
  final int? id;
  final String uuid;
  final int saleId;
  final String saleUuid;
  final int? customerId;
  final String? staffUuid;
  final String status;
  final int refundTotalMinor;
  final String refundMethod;
  final String? reason;
  final String createdAt;
  final String updatedAt;

  const SaleReturn({
    this.id,
    required this.uuid,
    required this.saleId,
    required this.saleUuid,
    this.customerId,
    this.staffUuid,
    required this.status,
    required this.refundTotalMinor,
    required this.refundMethod,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'uuid': uuid,
        'sale_id': saleId,
        'sale_uuid': saleUuid,
        'customer_id': customerId,
        'staff_uuid': staffUuid,
        'status': status,
        'refund_total_minor': refundTotalMinor,
        'refund_method': refundMethod,
        'reason': reason,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}

class SaleReturnItem {
  final int? id;
  final String uuid;
  final int returnId;
  final int saleItemId;
  final int productId;
  final String productUuid;
  final String productName;
  final double quantity;
  final int unitRefundMinor;
  final int lineRefundMinor;
  final String createdAt;

  const SaleReturnItem({
    this.id,
    required this.uuid,
    required this.returnId,
    required this.saleItemId,
    required this.productId,
    required this.productUuid,
    required this.productName,
    required this.quantity,
    required this.unitRefundMinor,
    required this.lineRefundMinor,
    required this.createdAt,
  });
}

/// Input line for creating a return against a completed sale.
class ReturnLineInput {
  final int saleItemId;
  final double quantity;

  const ReturnLineInput({required this.saleItemId, required this.quantity});
}
