import 'package:file_picker/file_picker.dart';

import '../../core/formats/supported_extensions.dart';

/// Unified file picker that delegates to the best native picker per platform.
///
/// Primary: `file_picker` (richer API, progress, cleanup, directory support)
/// Fallback: `file_selector` (official Flutter team, security hardening)
class BookFilePicker {
  static const _bookExtensions = supportedBookExtensions;

  /// Pick a single book file.
  /// Returns the file path or null if cancelled.
  Future<String?> pickBookFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: _bookExtensions,
    );
    return file?.path;
  }

  /// Pick multiple book files.
  /// Returns list of file paths (empty if cancelled).
  Future<List<String>> pickBookFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: _bookExtensions,
    );
    if (result == null) return [];
    return result.files.where((f) => f.path != null).map((f) => f.path!).toList();
  }

  /// Pick a single file with the given extensions.
  /// Returns the file path or null if cancelled.
  Future<String?> pickFile(List<String> allowedExtensions) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first.path;
  }

  /// Pick a directory for batch import.
  /// Returns the directory path or null if cancelled.
  Future<String?> pickDirectory() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Выберите папку с книгами',
    );
  }
}
