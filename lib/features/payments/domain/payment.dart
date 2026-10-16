import '../../../core/utils/time_utils.dart';

abstract final class PaymentMethods {
  static const String cash = 'cash';
  static const String card = 'card';
  static const String credit = 'credit';
  static const String creditCard = 'credit_card';
  static const String debitCard = 'debit_card';
  static const String qr = 'qr';
  static const String split = 'split';
  static const Set<String> paid = {cash, creditCard, debitCard, qr};
  static const Set<String> all = {
    cash,
    card,
    credit,
    creditCard,
    debitCard,
    qr,
    split
  };

  static String labelOf(String method) => switch (method) {
        cash => 'Cash',
        card => 'Card',
        credit => 'Customer credit',
        creditCard => 'Credit card',
        debitCard => 'Debit card',
        qr => 'QR',
        split => 'Split',
        _ => method,
      };
}

class Payment {
  final int? id;
  final String uuid;
  final int saleId;
  final String paymentMethod;
  final int amountMinor;
  final String? reference;
  final int? receivedMinor;
  final int? changeMinor;
  final String paidAt;
  final String? staffUuid;
  final String createdAt;

  const Payment({
    this.id,
    required this.uuid,
    required this.saleId,
    required this.paymentMethod,
    required this.amountMinor,
    this.reference,
    this.receivedMinor,
    this.changeMinor,
    required this.paidAt,
    this.staffUuid,
    required this.createdAt,
  });

  DateTime? get paidDateTime => tryParseIso(paidAt);
  DateTime? get createdDateTime => tryParseIso(createdAt);

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'uuid': uuid,
      'sale_id': saleId,
      'payment_method': paymentMethod,
      'amount_minor': amountMinor,
      'reference': reference,
      'received_minor': receivedMinor,
      'change_minor': changeMinor,
      'paid_at': paidAt,
      'staff_uuid': staffUuid,
      'created_at': createdAt,
    };
  }

  factory Payment.fromMap(Map<String, Object?> map) {
    return Payment(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      saleId: map['sale_id'] as int,
      paymentMethod: map['payment_method'] as String,
      amountMinor: (map['amount_minor'] as num).toInt(),
      reference: map['reference'] as String?,
      receivedMinor: (map['received_minor'] as num?)?.toInt(),
      changeMinor: (map['change_minor'] as num?)?.toInt(),
      paidAt: map['paid_at'] as String,
      staffUuid: map['staff_uuid'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}
