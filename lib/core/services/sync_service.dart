import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

enum SyncDirection { upload, download, both }

enum SyncStatus { idle, syncing, error, conflict }

enum BookSyncStatus { localOnly, remoteOnly, both, downloading, uploading }

class SyncConfig {
  const SyncConfig({
    required this.url,
    this.username,
    this.password,
    this.direction = SyncDirection.both,
    this.wifiOnly = true,
    this.autoSync = true,
  });

  final String url;
  final String? username;
  final String? password;
  final SyncDirection direction;
  final bool wifiOnly;
  final bool autoSync;

  Map<String, dynamic> toJson() => {
    'url': url,
    'username': username,
    'password': password,
    'direction': direction.index,
    'wifiOnly': wifiOnly,
    'autoSync': autoSync,
  };

  factory SyncConfig.fromJson(Map<String, dynamic> json) => SyncConfig(
    url: json['url'] as String,
    username: json['username'] as String?,
    password: json['password'] as String?,
    direction: SyncDirection.values[json['direction'] as int? ?? 2],
    wifiOnly: json['wifiOnly'] as bool? ?? true,
    autoSync: json['autoSync'] as bool? ?? true,
  );
}

class SyncConflict {
  const SyncConflict({
    required this.bookId,
    required this.localModified,
    required this.remoteModified,
    this.localVersion,
    this.remoteVersion,
  });

  final String bookId;
  final DateTime localModified;
  final DateTime remoteModified;
  final int? localVersion;
  final int? remoteVersion;

  bool get localIsNewer => localModified.isAfter(remoteModified);
  bool get remoteIsNewer => remoteModified.isAfter(localModified);
  bool get isIdentical => localModified.isAtSameMomentAs(remoteModified);
}

abstract class SyncClientBase {
  Future<bool> ping();
  Future<void> mkdir(String path);
  Future<List<String>> readDir(String path);
  Future<void> upload(String localPath, String remotePath);
  Future<void> download(String remotePath, String localPath);
  Future<void> remove(String remotePath);
}

class WebDavClient extends SyncClientBase {
  WebDavClient(this._dio, this._config);

  final Dio _dio;
  final SyncConfig _config;

  Options get _authOptions => Options(
    headers: _config.username != null
        ? {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${_config.username}:${_config.password}'))}',
          }
        : null,
  );

  @override
  Future<bool> ping() async {
    try {
      await _dio.request<dynamic>(_config.url, options: _authOptions.copyWith(method: 'PROPFIND'));
      return true;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> mkdir(String path) async {
    await _dio.request<dynamic>(
      '${_config.url}/$path',
      options: _authOptions.copyWith(method: 'MKCOL'),
    );
  }

  @override
  Future<List<String>> readDir(String path) async {
    final response = await _dio.request<dynamic>(
      '${_config.url}/$path',
      options: _authOptions.copyWith(
        method: 'PROPFIND',
        headers: {'Depth': '1'},
      ),
    );
    final items = <String>[];
    final xmlStr = response.data.toString();
    final doc = XmlDocument.parse(xmlStr);
    for (final response in doc.findAllElements('d:response')) {
      final href = response.findElements('d:href').firstOrNull?.innerText;
      if (href != null && !href.endsWith('/')) {
        items.add(href.split('/').last);
      }
    }
    return items;
  }

  @override
  Future<void> upload(String localPath, String remotePath) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    await _dio.put<dynamic>(
      '${_config.url}/$remotePath',
      data: Stream.fromIterable([bytes]),
      options: _authOptions.copyWith(
        headers: {'Content-Type': 'application/octet-stream'},
      ),
    );
  }

  @override
  Future<void> download(String remotePath, String localPath) async {
    final response = await _dio.get<List<int>>(
      '${_config.url}/$remotePath',
      options: _authOptions.copyWith(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null) throw Exception('Download failed: empty response');
    await File(localPath).writeAsBytes(data);
  }

  @override
  Future<void> remove(String remotePath) async {
    await _dio.request<dynamic>(
      '${_config.url}/$remotePath',
      options: _authOptions.copyWith(method: 'DELETE'),
    );
  }
}

class SyncService {
  SyncService(this._prefs);

  final SharedPreferences _prefs;
  static const _configKey = 'sync_config';
  static const _statusKey = 'sync_status';

  SyncConfig? _config;
  SyncStatus _status = SyncStatus.idle;
  SyncClientBase? _client;

  SyncConfig? get config => _config;
  SyncStatus get status => _status;

  void init() {
    final json = _prefs.getString(_configKey);
    if (json != null) {
      try {
        _config = SyncConfig.fromJson(
          Map<String, dynamic>.from(
            // ignore: avoid_dynamic_calls
            (Uri.dataFromString(json).data as Object?) as Map? ?? {},
          ),
        );
      } on Object catch (_) {}
    }
  }

  Future<void> configure(SyncConfig config) async {
    _config = config;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 30),
      ),
    );
    _client = WebDavClient(dio, config);
    await _prefs.setString(_configKey, Uri.encodeComponent('${config.toJson()}'));
  }

  Future<void> sync() async {
    if (_config == null || _client == null) return;
    _status = SyncStatus.syncing;
    await _prefs.setString(_statusKey, SyncStatus.syncing.index.toString());

    try {
      await _client!.ping();
      _status = SyncStatus.idle;
      await _prefs.setString(_statusKey, SyncStatus.idle.index.toString());
    } on Object catch (_) {
      _status = SyncStatus.error;
      await _prefs.setString(_statusKey, SyncStatus.error.index.toString());
    }
  }

  void disable() {
    _config = null;
    _client = null;
    unawaited(_prefs.remove(_configKey));
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  throw UnimplementedError('syncServiceProvider must be overridden at startup.');
});
