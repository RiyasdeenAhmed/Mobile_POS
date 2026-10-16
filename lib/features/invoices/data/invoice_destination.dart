import '../../../core/database/settings_repository.dart';
import '../../../core/platform/retail_files.dart';

class InvoiceDestination {
  InvoiceDestination(this.settings, this.files);
  final SettingsRepository settings;
  final RetailFiles files;
  static const key = 'invoice_folder_uri';
  Future<String?> get folder async {
    final value = await settings.getString(key);
    return value == null || value.isEmpty ? null : value;
  }

  Future<String?> choose() async {
    final uri = await files.chooseFolder();
    if (uri != null) await settings.setString(key, uri);
    return uri;
  }

  Future<void> reset() => settings.setString(key, '');
  Future<String?> save(String name, List<int> bytes,
          {bool saveAs = false}) async =>
      files.save(
          name: name.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_'),
          bytes: bytes,
          folder: saveAs ? null : await folder);
}
