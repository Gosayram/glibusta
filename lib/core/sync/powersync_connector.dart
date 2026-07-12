import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:powersync/powersync.dart';

/// Configurable [PowerSyncBackendConnector] for Glibusta.
///
/// Uses the backend URL and credentials provided at construction time.
/// Returns `null` from [fetchCredentials] when not configured, which means
/// the sync client will not attempt to connect.
class GlibustaSyncConnector extends PowerSyncBackendConnector {
  final String? _endpoint;
  final String? _token;
  final String? _userId;

  const GlibustaSyncConnector({
    String? endpoint,
    String? token,
    String? userId,
  }) : _endpoint = endpoint,
       _token = token,
       _userId = userId;

  bool get isConfigured => _endpoint != null && _token != null;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    if (!isConfigured) return null;

    return PowerSyncCredentials(
      endpoint: _endpoint!,
      token: _token!,
      userId: _userId,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    if (!isConfigured) return;

    final batch = await database.getCrudBatch();
    if (batch == null) return;

    final uri = Uri.parse('$_endpoint/api/sync/upload');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
        'X-User-Id': ?_userId,
      },
      body: jsonEncode({'changes': batch.crud.map((e) => e.toJson()).toList()}),
    );

    if (response.statusCode == 401) {
      invalidateCredentials();
      return;
    }

    if (response.statusCode != 200) {
      throw http.ClientException(
        'Upload failed: ${response.statusCode} ${response.reasonPhrase}',
        uri,
      );
    }

    await batch.complete();
  }
}
