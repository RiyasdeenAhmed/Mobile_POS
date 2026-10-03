import '../../../core/utils/time_utils.dart';

class Sale {
  final int? id;
  final String uuid;
  final String invoiceNumber;
  final String saleAt;
  final int? customerId;
  final String? staffUuid;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final int amountPaidMinor;
  final int changeMinor;
  final int amountDueMinor;
  final String status;
  final String paymentMethod;
  final String? notes;
  final String createdAt;
  final String updatedAt;

  const Sale({
    this.id,
    required this.uuid,
    required this.invoiceNumber,
    required this.saleAt,
    this.customerId,
    this.staffUuid,
    this.subtotalMinor = 0,
    this.discountMinor = 0,
    this.taxMinor = 0,
    this.totalMinor = 0,
    this.amountPaidMinor = 0,
    this.changeMinor = 0,
    this.amountDueMinor = 0,
    this.status = 'completed',
    this.paymentMethod = 'cash',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get saleDateTime => tryParseIso(saleAt);
  DateTime? get createdDateTime => tryParseIso(createdAt);

  Sale copyWith({
    int? id,
    String? uuid,
    String? invoiceNumber,
    String? saleAt,
    int? customerId,
    String? staffUuid,
    int? subtotalMinor,
    int? discountMinor,
    int? taxMinor,
    int? totalMinor,
    int? amountPaidMinor,
    int? changeMinor,
    int? amountDueMinor,
    String? status,
    String? paymentMethod,
    String? notes,
    String? createdAt,
    String? updatedAt,
  }) {
    return Sale(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      saleAt: saleAt ?? this.saleAt,
      customerId: customerId ?? this.customerId,
      staffUuid: staffUuid ?? this.staffUuid,
      subtotalMinor: subtotalMinor ?? this.subtotalMinor,
      discountMinor: discountMinor ?? this.discountMinor,
      taxMinor: taxMinor ?? this.taxMinor,
      totalMinor: totalMinor ?? this.totalMinor,
      amountPaidMinor: amountPaidMinor ?? this.amountPaidMinor,
      changeMinor: changeMinor ?? this.changeMinor,
      amountDueMinor: amountDueMinor ?? this.amountDueMinor,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'invoice_number': invoiceNumber,
      'sale_at': saleAt,
      'customer_id': customerId,
      'staff_uuid': staffUuid,
      'subtotal_minor': subtotalMinor,
      'discount_minor': discountMinor,
      'tax_minor': taxMinor,
      'total_minor': totalMinor,
      'amount_paid_minor': amountPaidMinor,
      'change_minor': changeMinor,
      'amount_due_minor': amountDueMinor,
      'status': status,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Sale.fromMap(Map<String, Object?> map) {
    return Sale(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      invoiceNumber: map['invoice_number'] as String,
      saleAt: map['sale_at'] as String,
      customerId: map['customer_id'] as int?,
      staffUuid: map['staff_uuid'] as String?,
      subtotalMinor: (map['subtotal_minor'] as int?) ?? 0,
      discountMinor: (map['discount_minor'] as int?) ?? 0,
      taxMinor: (map['tax_minor'] as int?) ?? 0,
      totalMinor: (map['total_minor'] as int?) ?? 0,
      amountPaidMinor: (map['amount_paid_minor'] as int?) ?? 0,
      changeMinor: (map['change_minor'] as int?) ?? 0,
      amountDueMinor: (map['amount_due_minor'] as int?) ?? 0,
      status: (map['status'] as String?) ?? 'completed',
      paymentMethod: (map['payment_method'] as String?) ?? 'cash',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
