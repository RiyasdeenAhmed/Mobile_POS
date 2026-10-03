import '../../../core/utils/time_utils.dart';

class Customer {
  final int? id;
  final String uuid;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final int creditLimitMinor;
  final int balanceMinor;
  final bool isActive;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  const Customer({
    this.id,
    required this.uuid,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.creditLimitMinor = 0,
    this.balanceMinor = 0,
    this.isActive = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get createdDateTime => tryParseIso(createdAt);
  DateTime? get updatedDateTime => tryParseIso(updatedAt);

  Customer copyWith({
    int? id,
    String? uuid,
    String? name,
    String? phone,
    String? email,
    String? address,
    int? creditLimitMinor,
    int? balanceMinor,
    bool? isActive,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return Customer(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      creditLimitMinor: creditLimitMinor ?? this.creditLimitMinor,
      balanceMinor: balanceMinor ?? this.balanceMinor,
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
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'credit_limit_minor': creditLimitMinor,
      'balance_minor': balanceMinor,
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    return Customer(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      address: map['address'] as String?,
      creditLimitMinor: (map['credit_limit_minor'] as int?) ?? 0,
      balanceMinor: (map['balance_minor'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
