import 'package:flutter/services.dart';

final class DjvuDocument {
  const DjvuDocument({
    required this.path,
    required this.pageCount,
  });

  final String path;
  final int pageCount;
}

abstract interface class DjvuEngine {
  Future<DjvuDocument> open(String path);

  Future<Uint8List> renderPage({
    required String path,
    required int pageIndex,
    required int width,
    required int height,
    double scale = 1,
  });

  Future<String?> extractPageText({
    required String path,
    required int pageIndex,
  });

  Future<void> close(String path);
}

final class MethodChannelDjvuEngine implements DjvuEngine {
  MethodChannelDjvuEngine() : _channel = const MethodChannel('glibusta/djvu');

  final MethodChannel _channel;

  @override
  Future<DjvuDocument> open(String path) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('open', {'path': path});
    final pageCount = result?['pageCount'] as int?;
    if (pageCount == null) {
      throw StateError('DjVu open failed: missing pageCount');
    }
    return DjvuDocument(path: path, pageCount: pageCount);
  }

  @override
  Future<Uint8List> renderPage({
    required String path,
    required int pageIndex,
    required int width,
    required int height,
    double scale = 1,
  }) async {
    final bytes = await _channel.invokeMethod<Uint8List>('renderPage', {
      'path': path,
      'pageIndex': pageIndex,
      'width': width,
      'height': height,
      'scale': scale,
    });
    if (bytes == null) throw StateError('DjVu render failed');
    return bytes;
  }

  @override
  Future<String?> extractPageText({
    required String path,
    required int pageIndex,
  }) {
    return _channel.invokeMethod<String>('extractText', {
      'path': path,
      'pageIndex': pageIndex,
    });
  }

  @override
  Future<void> close(String path) {
    return _channel.invokeMethod<void>('close', {'path': path});
  }
}
