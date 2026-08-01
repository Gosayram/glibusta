import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/formats/format_capability.dart';
import '../../../core/http/http_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../search/data/composite_source.dart';

/// In-memory override of file paths for books opened via "read online".
/// `BookFileRepository` consults this before the downloads/savedBooks tables,
/// so the existing reader pipeline (which resolves files by bookId) opens the
/// temp copy transparently.
class OnlineReadRegistry {
  final Map<String, String> _paths = {};

  String? pathFor(String bookId) => _paths[bookId];
  void register(String bookId, String path) => _paths[bookId] = path;
  String? unregister(String bookId) => _paths.remove(bookId);
}

final onlineReadRegistryProvider = Provider<OnlineReadRegistry>((ref) => OnlineReadRegistry());

/// Readable formats for in-app online reading, best first.
const _onlineReadPreference = <BookFormat>[
  BookFormat.epub,
  BookFormat.fb2,
  BookFormat.txt,
  BookFormat.rtf,
  BookFormat.docx,
  BookFormat.mobi,
  BookFormat.cbz,
];

BookFormat? _pickReadableFormat(List<BookFormat> available) {
  final set = available.toSet();
  for (final f in _onlineReadPreference) {
    if (set.contains(f) && f.canReadInApp) return f;
  }
  for (final f in available) {
    if (f.canReadInApp) return f;
  }
  return null;
}

/// Fetches a readable format of a book into a temp cache and registers the path
/// so the reader opens it without a permanent library download.
class OnlineReadService {
  OnlineReadService(this._ref);

  final Ref _ref;

  Future<String> prepare(
    String bookId,
    List<BookFormat> availableFormats, {
    void Function(int received, int total)? onProgress,
  }) async {
    final format = _pickReadableFormat(availableFormats);
    if (format == null) {
      throw const OnlineReadFailure('Нет читаемого формата для онлайн-чтения');
    }

    final registry = _ref.read(onlineReadRegistryProvider);
    final previous = registry.unregister(bookId);
    if (previous != null) unawaited(_safeDelete(previous));

    final url = await _ref.read(bookSourceProvider).getDownloadUrl(bookId, format);
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/glibusta_online_read');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final savePath = '${dir.path}/$bookId.${format.name}';

    try {
      await _ref.read(httpClientProvider).download(url, savePath, onProgress: onProgress);
    } on HttpException catch (e) {
      throw OnlineReadFailure(e.message);
    }

    registry.register(bookId, savePath);
    AppLogger().info('Online read prepared: $bookId -> $savePath', name: 'OnlineRead');
    return savePath;
  }

  /// Removes the temp file and registry entry when the reader route closes.
  Future<void> dispose(String bookId) async {
    final path = _ref.read(onlineReadRegistryProvider).unregister(bookId);
    if (path != null) await _safeDelete(path);
  }

  Future<void> _safeDelete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } on Object {
      // best-effort cleanup
    }
  }
}

final onlineReadServiceProvider = Provider<OnlineReadService>((ref) => OnlineReadService(ref));

class OnlineReadFailure implements Exception {
  const OnlineReadFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
