import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/platform/app_file_storage.dart';
import '../../reader/data/parsers/format_detector.dart';
import 'book_import_service.dart';

final libraryScannerProvider = Provider<LibraryScanner>((ref) {
  final importService = ref.watch(bookImportServiceProvider);
  final storage = ref.watch(appFileStorageProvider);
  return LibraryScanner(importService, storage);
});

/// Result of a library scan operation.
class ScanResult {
  final int imported;
  final int skipped;
  final int errors;
  final String? error;

  const ScanResult({this.imported = 0, this.skipped = 0, this.errors = 0, this.error});

  bool get hasError => error != null;
  bool get isEmpty => imported == 0 && skipped == 0 && errors == 0;
}

/// Lazy background scanner for the books directory.
class LibraryScanner {
  LibraryScanner(this._importService, this._storage);

  final BookImportService _importService;
  final AppFileStorage _storage;
  final _logger = AppLogger();
  bool _scanning = false;

  bool get isScanning => _scanning;

  /// Scan the books directory for new files and import them.
  /// Runs lazily in background — non-blocking.
  Future<void> scanLazy() async {
    if (_scanning) return;
    _scanning = true;
    try {
      await _doScan();
    } on Object catch (e) {
      _logger.warning('Library scan failed: $e', name: 'LibraryScanner', error: e);
    } finally {
      _scanning = false;
    }
  }

  /// Scan with result callback — for manual rescan from settings.
  Future<ScanResult> scanWithResult() async {
    if (_scanning) {
      return const ScanResult(error: 'Сканирование уже выполняется');
    }
    _scanning = true;
    try {
      return await _doScan();
    } on Object catch (e) {
      _logger.warning('Library scan failed: $e', name: 'LibraryScanner', error: e);
      return ScanResult(error: e.toString());
    } finally {
      _scanning = false;
    }
  }

  Future<ScanResult> _doScan() async {
    final booksDir = await _storage.booksDir();
    if (!await booksDir.exists()) {
      return const ScanResult();
    }

    final importableFiles = <File>[];
    await for (final entity in booksDir.list(recursive: true)) {
      if (entity is File) {
        final ext = entity.path.split('.').last.toLowerCase();
        if (importableExtensions.contains(ext)) {
          importableFiles.add(entity);
        }
      }
    }

    if (importableFiles.isEmpty) {
      return const ScanResult();
    }

    var imported = 0;
    var skipped = 0;
    var errors = 0;
    var consecutiveFailures = 0;

    for (final file in importableFiles) {
      final result = await _importService.importFile(file.path);
      if (result.isSuccess) {
        imported++;
        consecutiveFailures = 0;
      } else if (result.isDuplicate) {
        skipped++;
        consecutiveFailures = 0;
      } else {
        errors++;
        consecutiveFailures++;
        if (consecutiveFailures >= 3) {
          _logger.warning(
            'Scan circuit breaker triggered after $consecutiveFailures failures',
            name: 'LibraryScanner',
          );
          break;
        }
      }
    }

    _logger.info(
      'Scan complete: $imported imported, $skipped skipped, $errors errors',
      name: 'LibraryScanner',
    );
    return ScanResult(imported: imported, skipped: skipped, errors: errors);
  }
}
