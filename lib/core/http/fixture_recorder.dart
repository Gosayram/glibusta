import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';

/// Captures Flibusta HTML/XML responses to disk so parsers can be developed
/// against real pages.
///
/// This records user-driven app traffic (a user opens a book, searches, etc.),
/// not crawling. Enable at compile time with
/// `flutter run --dart-define=RECORD_FIXTURES=true`. Captured bodies land in
/// `<app-documents>/fixtures/<category>/<name>.{html,xml}` plus an append-only
/// `record.jsonl` manifest. Zero overhead when the flag is off — the
/// interceptor is not added to the chain.
class FixtureRecorderInterceptor extends Interceptor {
  FixtureRecorderInterceptor({required AppLogger logger}) : _logger = logger;

  final AppLogger _logger;
  Directory? _baseDir;

  static const _textContentTypes = <String>[
    'text/html',
    'application/xml',
    'text/xml',
    'application/atom+xml',
    'application/rss+xml',
  ];

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final status = response.statusCode ?? 0;
    final contentType = (response.headers.value('content-type') ?? '').toLowerCase();
    if (status >= 200 &&
        status < 300 &&
        _textContentTypes.any(contentType.contains)) {
      final bytes = _toBytes(response.data);
      if (bytes != null && bytes.isNotEmpty) {
        unawaited(_record(response, bytes, contentType));
      }
    }
    handler.next(response);
  }

  Uint8List? _toBytes(dynamic data) {
    if (data is Uint8List) return data;
    if (data is String) return Uint8List.fromList(utf8.encode(data));
    return null;
  }

  Future<void> _record(Response<dynamic> response, Uint8List bytes, String contentType) async {
    try {
      final base = await _ensureBaseDir();
      final uri = response.requestOptions.uri;
      final isXml = contentType.contains('xml') || contentType.contains('atom');
      final ext = isXml ? 'xml' : 'html';
      final category = _categoryFor(uri.path);
      final name = _nameFor(uri);
      final rel = '$category/$name.$ext';

      final file = File('${base.path}/$rel');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      final entry = <String, Object?>{
        'ts': DateTime.now().toUtc().toIso8601String(),
        'method': response.requestOptions.method,
        'url': uri.toString(),
        'path': uri.path,
        'query': uri.query,
        'status': response.statusCode,
        'content_type': contentType,
        'bytes': bytes.length,
        'sha256': sha256.convert(bytes).toString(),
        'file': rel,
      };
      await File('${base.path}/record.jsonl').writeAsString(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } on Object catch (e) {
      _logger.warning('Fixture recording failed: $e', name: 'FixtureRecorder');
    }
  }

  Future<Directory> _ensureBaseDir() async {
    if (_baseDir != null) return _baseDir!;
    final docs = await getApplicationDocumentsDirectory();
    return _baseDir = Directory('${docs.path}/fixtures');
  }

  static String _categoryFor(String path) {
    final first = path.replaceAll(RegExp(r'^/+|/+$'), '').split('/').firstOrNull ?? '';
    return const {
      'b': 'book',
      'a': 'author',
      'g': 'genre',
      's': 'series',
      'sequence': 'series',
      'booksearch': 'search',
      'opds': 'opds',
      'new': 'recent',
      'stat': 'stat',
    }[first] ??
        'misc';
  }

  static String _nameFor(Uri uri) {
    final path = uri.path.replaceAll(RegExp(r'^/+|/+$'), '');
    final base = path.isEmpty
        ? 'root'
        : path.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final capped = base.length > 56 ? '${base.substring(0, 48)}_${base.length}' : base;
    if (uri.query.isEmpty) return capped;
    final q = sha1.convert(utf8.encode(uri.query)).toString().substring(0, 8);
    return '${capped.length > 48 ? capped.substring(0, 48) : capped}_$q';
  }
}
