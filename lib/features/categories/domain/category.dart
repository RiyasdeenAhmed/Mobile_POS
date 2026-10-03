import '../../../core/utils/time_utils.dart';

class Category {
  final int? id;
  final String uuid;
  final String name;
  final int? parentId;
  final int sortOrder;
  final bool isActive;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  const Category({
    this.id,
    required this.uuid,
    required this.name,
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime? get createdDateTime => tryParseIso(createdAt);
  DateTime? get updatedDateTime => tryParseIso(updatedAt);

  Category copyWith({
    int? id,
    String? uuid,
    String? name,
    int? parentId,
    int? sortOrder,
    bool? isActive,
    bool? isArchived,
    String? createdAt,
    String? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      sortOrder: sortOrder ?? this.sortOrder,
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
      'parent_id': parentId,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Category.fromMap(Map<String, Object?> map) {
    return Category(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      name: map['name'] as String,
      parentId: map['parent_id'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      isArchived: ((map['is_archived'] as int?) ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }
}
