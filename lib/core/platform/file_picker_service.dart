import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

/// Unified file picker that delegates to the best native picker per platform.
///
/// Primary: `file_picker` (richer API, progress, cleanup, directory support)
/// Fallback: `file_selector` (official Flutter team, security hardening)
class BookFilePicker {
  static const _bookExtensions = ['epub', 'fb2', 'zip', 'txt', 'rtf', 'mobi', 'djvu', 'djv'];

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

  /// Pick a directory for batch import.
  /// Returns the directory path or null if cancelled.
  Future<String?> pickDirectory() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Выберите папку с книгами',
    );
  }

  /// Pick a single book file using file_selector (SAF fallback).
  Future<String?> pickBookFileFallback() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'EPUB', extensions: ['epub']),
        const XTypeGroup(label: 'FB2', extensions: ['fb2', 'zip']),
        const XTypeGroup(label: 'TXT', extensions: ['txt']),
        const XTypeGroup(label: 'RTF', extensions: ['rtf']),
        const XTypeGroup(label: 'MOBI', extensions: ['mobi']),
        const XTypeGroup(label: 'DJVU', extensions: ['djvu', 'djv']),
      ],
    );
    return file?.path;
  }

  /// Pick multiple book files using file_selector (SAF fallback).
  Future<List<String>> pickBookFilesFallback() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Books', extensions: _bookExtensions),
      ],
    );
    return files.map((f) => f.path).toList();
  }

  /// Pick a directory using file_selector (SAF fallback).
  Future<String?> pickDirectoryFallback() async {
    return getDirectoryPath();
  }
}
