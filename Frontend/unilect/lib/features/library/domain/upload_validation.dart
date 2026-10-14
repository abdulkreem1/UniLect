import '../../../core/network/api_client.dart';
import '../../settings/domain/client_config.dart';

sealed class UploadProblem {
  const UploadProblem();
}

class FileTypeNotAllowed extends UploadProblem {
  const FileTypeNotAllowed(this.extension);
  final String extension;
}

class FileTooLarge extends UploadProblem {
  const FileTooLarge(this.maxMb);
  final int maxMb;
}

/// Client-side pre-check against the server's current limits (FR-043).
/// The server re-validates extension, magic bytes and size; this only spares
/// the user a pointless upload.
UploadProblem? checkUpload(UploadFile file, ClientConfig config) {
  final ext = file.extension;
  if (ext.isEmpty || !config.allowedExtensions.contains(ext)) {
    return FileTypeNotAllowed(ext);
  }
  if (file.sizeBytes > config.maxUploadBytes) {
    return FileTooLarge(config.maxUploadSizeMb);
  }
  return null;
}
