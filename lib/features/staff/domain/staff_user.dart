import '../../../core/utils/time_utils.dart';

class StaffUser {
  final int? id;
  final String uuid;
  final String username;
  final String displayName;
  final String role;
  final String? passwordHash;
  final int? pinLength;
  final bool mustChangePin;
  final bool isActive;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  const StaffUser({
    this.id,
    required this.uuid,
    required this.username,
    required this.displayName,
    this.role = 'cashier',
    this.passwordHash,
    this.pinLength,
    this.mustChangePin = false,
    this.isActive = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get createdDateTime => tryParseIso(createdAt);
  DateTime? get updatedDateTime => tryParseIso(updatedAt);

  StaffUser copyWith({
    int? id,
    String? uuid,
    String? username,
    String? displayName,
    String? role,
    String? passwordHash,
    int? pinLength,
    bool? mustChangePin,
    bool? isActive,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return StaffUser(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      pinLength: pinLength ?? this.pinLength,
      mustChangePin: mustChangePin ?? this.mustChangePin,
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
      'username': username,
      'display_name': displayName,
      'role': role,
      'password_hash': passwordHash,
      if (pinLength != null) 'pin_length': pinLength,
      'must_change_pin': mustChangePin ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory StaffUser.fromMap(Map<String, Object?> map) {
    return StaffUser(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
      role: (map['role'] as String?) ?? 'cashier',
      passwordHash: map['password_hash'] as String?,
      pinLength: (map['pin_length'] as num?)?.toInt(),
      mustChangePin: ((map['must_change_pin'] as int?) ?? 0) == 1,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
