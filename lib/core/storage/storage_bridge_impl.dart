import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_book_file.dart';
import 'storage_bridge.dart';

final storageBridgeProvider = Provider<StorageBridge>((ref) {
  return StorageBridgeImpl();
});

class StorageBridgeImpl implements StorageBridge {
  static const _channel = MethodChannel('com.gosayram.glibusta/storage_bridge');

  @override
  Future<String?> pickFolder() async {
    try {
      final uri = await _channel.invokeMethod<String>('pickFolder');
      return uri;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<ExternalBookFile>> scanBooks(String folderUri) async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>(
        'scanBooks',
        {'uri': folderUri},
      );
      if (result == null) return [];
      return result.map((item) {
        final map = item as Map<dynamic, dynamic>;
        return ExternalBookFile(
          uri: map['uri'] as String,
          name: map['name'] as String,
          size: map['size'] as int,
          extension: map['extension'] as String,
          mimeType: map['mimeType'] as String?,
          lastModified: map['lastModified'] as int?,
        );
      }).toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<Uint8List> readFile(String fileUri) async {
    try {
      final bytes = await _channel.invokeMethod<Uint8List>(
        'readFile',
        {'uri': fileUri},
      );
      return bytes ?? Uint8List(0);
    } on PlatformException {
      return Uint8List(0);
    }
  }

  @override
  Future<String?> copyToCache(String fileUri) async {
    try {
      final path = await _channel.invokeMethod<String>(
        'copyToCache',
        {'uri': fileUri},
      );
      return path;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<List<String>> getPersistedUris() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getPersistedUris');
      if (result == null) return [];
      return result.cast<String>();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<bool> forgetUri(String uri) async {
    try {
      await _channel.invokeMethod<bool>('forgetUri', {'uri': uri});
      return true;
    } on PlatformException {
      return false;
    }
  }
}
