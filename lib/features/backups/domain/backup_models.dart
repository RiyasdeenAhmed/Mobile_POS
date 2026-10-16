enum BackupStatus { pending, completed, failed }

class BackupArchive {
  final String path;
  final String checksum;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;

  const BackupArchive({
    required this.path,
    required this.checksum,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
  });
}

class BackupSettings {
  final bool automatic;
  final int retention;
  const BackupSettings({this.automatic = false, this.retention = 5});
}

class BackupStatusInfo {
  final BackupStatus status;
  final DateTime? lastSuccessfulSync;
  final String? error;
  const BackupStatusInfo({required this.status, this.lastSuccessfulSync, this.error});
}
