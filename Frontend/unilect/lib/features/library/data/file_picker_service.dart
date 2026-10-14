import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Thin wrapper over the platform picker so screens stay testable.
class FilePickerService {
  const FilePickerService();

  Future<List<UploadFile>> pick({
    required List<String> extensions,
    bool multiple = false,
  }) async {
    final files = multiple
        ? await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: extensions,
          )
        : [
            ?await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: extensions,
            ),
          ];
    return [
      for (final f in files)
        UploadFile(
          name: f.name,
          sizeBytes: await f.length() ?? 0,
          readBytes: f.readAsBytes,
        ),
    ];
  }
}

final filePickerServiceProvider = Provider<FilePickerService>(
  (ref) => const FilePickerService(),
);
