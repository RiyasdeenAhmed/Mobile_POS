import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'audit_event.dart';

class AuditRepository {
  final AppDatabase database;
  final Uuid _uuid;

  AuditRepository(this.database, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  Future<void> append({
    required String eventType,
    String? actorStaffUuid,
    String? entityType,
    String? entityId,
    String details = '{}',
  }) async {
    final event = AuditEvent(
      uuid: _uuid.v4(),
      eventType: eventType,
      actorStaffUuid: actorStaffUuid,
      entityType: entityType,
      entityId: entityId,
      details: details,
      createdAt: DateTime.now().toUtc(),
    );
    await database.db.insert('audit_events', event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  Future<List<AuditEvent>> list({int limit = 100, int offset = 0}) async {
    final rows = await database.db.query(
      'audit_events',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(AuditEvent.fromMap).toList(growable: false);
  }
}
