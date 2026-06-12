import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logging/app_logger.dart';

class ApiVersionConfig {
  const ApiVersionConfig({
    this.version = 1,
    this.baseUrl = '',
    this.isLegacy = false,
  });

  final int version;
  final String baseUrl;
  final bool isLegacy;

  ApiVersionConfig copyWith({int? version, String? baseUrl, bool? isLegacy}) {
    return ApiVersionConfig(
      version: version ?? this.version,
      baseUrl: baseUrl ?? this.baseUrl,
      isLegacy: isLegacy ?? this.isLegacy,
    );
  }
}

class ApiVersionManager {
  ApiVersionManager(this._logger);
  final AppLogger _logger;

  int _currentVersion = 1;
  int get currentVersion => _currentVersion;

  final Map<int, String> _endpoints = {
    1: '',
    2: '/api/v2',
  };

  String buildUrl(String baseUrl, String path, {int? version}) {
    final v = version ?? _currentVersion;
    final prefix = _endpoints[v] ?? '';
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return '$cleanBase$prefix$path';
  }

  void setVersion(int version) {
    if (!_endpoints.containsKey(version)) {
      _logger.warning('Unknown API version: $version', name: 'ApiVersion');
      return;
    }
    _currentVersion = version;
    _logger.info('API version set to $version', name: 'ApiVersion');
  }

  bool supportsFeature(String feature) {
    switch (feature) {
      case 'advanced_search':
        return _currentVersion >= 2;
      case 'reading_lists':
        return _currentVersion >= 2;
      default:
        return true;
    }
  }

  String normalizeResponse(Map<String, dynamic> response, int fromVersion) {
    if (fromVersion == _currentVersion) return response.toString();
    final result = Map<String, dynamic>.from(response);

    if (fromVersion == 1 && _currentVersion == 2) {
      if (result.containsKey('results')) {
        result['items'] = result.remove('results');
      }
      if (result.containsKey('total_results')) {
        result['total'] = result.remove('total_results');
      }
    }

    if (fromVersion == 2 && _currentVersion == 1) {
      if (result.containsKey('items')) {
        result['results'] = result.remove('items');
      }
      if (result.containsKey('total')) {
        result['total_results'] = result.remove('total');
      }
    }

    return result.toString();
  }

  int detectVersion(Map<String, dynamic> headers) {
    final versionHeader = headers['x-api-version']?.toString();
    if (versionHeader != null) {
      final v = int.tryParse(versionHeader);
      if (v != null && _endpoints.containsKey(v)) return v;
    }
    return 1;
  }
}

// --- Riverpod providers ---

final apiVersionManagerProvider = Provider<ApiVersionManager>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return ApiVersionManager(logger);
});

final apiVersionConfigProvider = Provider<ApiVersionConfig>((ref) {
  return const ApiVersionConfig();
});
