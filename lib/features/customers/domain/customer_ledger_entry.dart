class CustomerLedgerEntry {
  final int? id;
  final String uuid;
  final int customerId;
  final String entryType;
  final int amountMinor;
  final int balanceAfterMinor;
  final String? saleUuid;
  final int? saleId;
  final String? note;
  final String? staffUuid;
  final String createdAt;

  const CustomerLedgerEntry({
    this.id,
    required this.uuid,
    required this.customerId,
    required this.entryType,
    required this.amountMinor,
    required this.balanceAfterMinor,
    this.saleUuid,
    this.saleId,
    this.note,
    this.staffUuid,
    required this.createdAt,
  });

  factory CustomerLedgerEntry.fromMap(Map<String, Object?> row) {
    return CustomerLedgerEntry(
      id: row['id'] as int?,
      uuid: row['uuid'] as String,
      customerId: row['customer_id'] as int,
      entryType: row['entry_type'] as String,
      amountMinor: row['amount_minor'] as int,
      balanceAfterMinor: row['balance_after_minor'] as int,
      saleUuid: row['sale_uuid'] as String?,
      saleId: row['sale_id'] as int?,
      note: row['note'] as String?,
      staffUuid: row['staff_uuid'] as String?,
      createdAt: row['created_at'] as String,
    );
  }

  bool get isDebt => entryType == 'debt_sale';
  bool get isRepayment => entryType == 'repayment';
  bool get isReturnCredit => entryType == 'return_credit';
}
