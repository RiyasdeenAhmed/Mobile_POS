class AuditEvent {
  final String uuid;
  final String eventType;
  final String? actorStaffUuid;
  final String? entityType;
  final String? entityId;
  final String details;
  final DateTime createdAt;

  const AuditEvent({
    required this.uuid,
    required this.eventType,
    this.actorStaffUuid,
    this.entityType,
    this.entityId,
    this.details = '{}',
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'uuid': uuid,
        'event_type': eventType,
        'actor_staff_uuid': actorStaffUuid,
        'entity_type': entityType,
        'entity_id': entityId,
        'details': details,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory AuditEvent.fromMap(Map<String, Object?> map) => AuditEvent(
        uuid: map['uuid']! as String,
        eventType: map['event_type']! as String,
        actorStaffUuid: map['actor_staff_uuid'] as String?,
        entityType: map['entity_type'] as String?,
        entityId: map['entity_id'] as String?,
        details: map['details'] as String? ?? '{}',
        createdAt: DateTime.parse(map['created_at']! as String).toUtc(),
      );
}
