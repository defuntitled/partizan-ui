import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Opening and saving route list files; faked in tests.
abstract interface class RouteFiles {
  /// The text of a file the user picks; `null` if they cancel.
  Future<String?> open();

  /// Saves `text` where the user picks; `false` if they cancel.
  Future<bool> save(String fileName, String text);
}

class PickerRouteFiles implements RouteFiles {
  const PickerRouteFiles();

  @override
  Future<String?> open() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'csv', 'lst'],
    );
    if (files.isEmpty) return null;
    // Lenient: a stray byte must not fail the import, the parser rejects the entry.
    return utf8.decode(await files.single.readAsBytes(), allowMalformed: true);
  }

  @override
  Future<bool> save(String fileName, String text) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(text)),
      mimeType: 'text/plain',
    );
    return uri != null;
  }
}
