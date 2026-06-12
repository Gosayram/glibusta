import 'package:flutter/material.dart';

enum CoverSize { thumb, medium, large }

class CoverService {
  CoverService({String? baseUrl}) : _baseUrl = baseUrl;
  CoverService._() : _baseUrl = null;
  static final CoverService _instance = CoverService._();
  static CoverService get instance => _instance;

  final String? _baseUrl;

  static const Map<CoverSize, String> _suffixes = {
    CoverSize.thumb: '_t80x120',
    CoverSize.medium: '_t200x300',
    CoverSize.large: '_t400x600',
  };

  String? getUrl(String? coverPath, CoverSize size) {
    if (coverPath == null || coverPath.trim().isEmpty) return null;
    final suffix = _suffixes[size] ?? '';
    final path = coverPath.trim();

    if (path.startsWith('http')) {
      return _applySuffix(path, suffix);
    }
    if (_baseUrl != null) {
      final base = _baseUrl.endsWith('/') ? _baseUrl : '$_baseUrl/';
      return _applySuffix('$base$path', suffix);
    }
    return _applySuffix(path, suffix);
  }

  String _applySuffix(String url, String suffix) {
    if (suffix.isEmpty) return url;
    final lastDot = url.lastIndexOf('.');
    final queryStart = url.indexOf('?', lastDot >= 0 ? lastDot : 0);
    if (lastDot > 0 && (queryStart < 0 || lastDot < queryStart)) {
      return '${url.substring(0, lastDot)}$suffix${url.substring(lastDot)}';
    }
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}size=$suffix';
  }

  Widget buildPlaceholder(BuildContext context, CoverSize size) {
    final dims = switch (size) {
      CoverSize.thumb => 48.0,
      CoverSize.medium => 80.0,
      CoverSize.large => 120.0,
    };
    return Container(
      width: dims,
      height: dims * 1.5,
      color: Colors.grey[200],
      child: Icon(Icons.book, size: dims * 0.5, color: Colors.grey[400]),
    );
  }
}
