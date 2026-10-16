import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:path/path.dart' as p;

/// Android content URIs remain opaque; desktop uses native filesystem pickers.
class RetailFiles {
  static const channel = MethodChannel('qubex/retail_files');
  Future<String?> chooseFolder() => Platform.isAndroid
      ? channel.invokeMethod<String>('folder')
      : fs.getDirectoryPath();
  Future<String?> readCsv() async {
    if (Platform.isAndroid) return channel.invokeMethod<String>('csv');
    final file = await fs.openFile(acceptedTypeGroups: [
      const fs.XTypeGroup(label: 'CSV', extensions: ['csv'])
    ]);
    if (file == null) return null;
    if (await file.length() > 5 * 1024 * 1024) {
      throw const FormatException('CSV exceeds 5 MB');
    }
    return file.readAsString();
  }

  Future<void> openBarcodeApp() => channel.invokeMethod<void>('barcodeApp');
  Future<String?> save(
      {required String name,
      required List<int> bytes,
      String mime = 'application/pdf',
      String? folder}) async {
    if (Platform.isAndroid) {
      return channel.invokeMethod<String>('save', {
        'name': name,
        'bytes': Uint8List.fromList(bytes),
        'mime': mime,
        'folder': folder
      });
    }
    String? target;
    if (folder == null) {
      target = (await fs.getSaveLocation(suggestedName: name))?.path;
    } else {
      if (!await Directory(folder).exists()) {
        throw const FileSystemException('Destination unavailable');
      }
      target = p.join(folder, name);
      var n = 1;
      while (await File(target!).exists()) {
        target = p.join(folder,
            '${p.basenameWithoutExtension(name)} (${n++})${p.extension(name)}');
      }
    }
    if (target == null) return null;
    await File(target).writeAsBytes(bytes, flush: true);
    return target;
  }
}
