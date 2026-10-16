import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../domain/backup_models.dart';

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);
  @override
  String toString() => message;
}

abstract interface class CloudBackupClient {
  Future<void> upload(File encryptedArchive);
}

class UnavailableCloudBackupClient implements CloudBackupClient {
  @override
  Future<void> upload(File encryptedArchive) async =>
      throw const BackupException('Cloud backup is not connected');
}

class BackupService {
  final AppDatabase database;
  final CloudBackupClient cloud;
  final Uuid _uuid;
  final String appVersion;

  BackupService(this.database, {CloudBackupClient? cloud, Uuid? uuid, this.appVersion = '1.0.0'})
      : cloud = cloud ?? UnavailableCloudBackupClient(),
        _uuid = uuid ?? const Uuid();

  Future<BackupArchive> createEncrypted({required String password}) async {
    if (password.length < 8) throw const BackupException('Backup password must be at least 8 characters');
    final dir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(dir.path, 'backups'))..createSync(recursive: true);
    final id = _uuid.v4();
    final rawPath = p.join(backupDir.path, '$id.sqlite');
    final archivePath = p.join(backupDir.path, '$id.qbxbackup');
    await database.db.execute('VACUUM INTO ?', [rawPath]);
    final raw = await File(rawPath).readAsBytes();
    final checksum = await Sha256().hash(raw);
    final keyHash = await Sha256().hash(utf8.encode(password));
    final algorithm = AesGcm.with256bits();
    final box = await algorithm.encrypt(raw, secretKey: SecretKey(keyHash.bytes));
    final payload = <String, Object?>{
      'schemaVersion': AppDatabase.schemaVersion,
      'appVersion': appVersion,
      'storeIdentifier': id,
      'checksum': base64UrlEncode(checksum.bytes),
      'nonce': base64UrlEncode(box.nonce),
      'mac': base64UrlEncode(box.mac.bytes),
      'ciphertext': base64UrlEncode(box.cipherText),
    };
    await File(archivePath).writeAsString(jsonEncode(payload), flush: true);
    await File(rawPath).delete();
    await database.db.insert('backup_records', {
      'uuid': id,
      'path': archivePath,
      'checksum': base64UrlEncode(checksum.bytes),
      'schema_version': AppDatabase.schemaVersion,
      'app_version': appVersion,
      'status': BackupStatus.completed.name,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    });
    return BackupArchive(path: archivePath, checksum: base64UrlEncode(checksum.bytes), schemaVersion: AppDatabase.schemaVersion, appVersion: appVersion, createdAt: DateTime.now().toUtc());
  }

  Future<Uint8List> decryptAndValidate(File archive, {required String password}) async {
    final payload = jsonDecode(await archive.readAsString()) as Map<String, dynamic>;
    if (payload['schemaVersion'] != AppDatabase.schemaVersion) throw const BackupException('Backup schema is incompatible');
    final keyHash = await Sha256().hash(utf8.encode(password));
    final box = SecretBox(base64Url.decode(payload['ciphertext'] as String), nonce: base64Url.decode(payload['nonce'] as String), mac: Mac(base64Url.decode(payload['mac'] as String)));
    final raw = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(keyHash.bytes));
    final checksum = await Sha256().hash(raw);
    if (base64UrlEncode(checksum.bytes) != payload['checksum']) throw const BackupException('Backup checksum validation failed');
    return Uint8List.fromList(raw);
  }

  Future<File> prepareRestore(File archive, {required String password}) async {
    final raw = await decryptAndValidate(archive, password: password);
    if (raw.isEmpty) throw const BackupException('Backup database is empty');
    final dir = await getApplicationDocumentsDirectory();
    final safetyDir = Directory(p.join(dir.path, 'backups', 'safety'))
      ..createSync(recursive: true);
    final safety = File(p.join(
      safetyDir.path,
      'before-restore-${DateTime.now().toUtc().millisecondsSinceEpoch}.sqlite',
    ));
    await database.db.execute('VACUUM INTO ?', [safety.path]);
    return safety;
  }
}
