import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/dio_provider.dart';
import '../logging/app_logger.dart';

part 'auth_repository.g.dart';
part 'auth_repository.freezed.dart';

const _kSessionNameKey = 'auth_session_name';
const _kSessionMailKey = 'auth_session_mail';
const _kSessionCookiesKey = 'auth_session_cookies';

@JsonSerializable()
class UserSession {
  final String name;
  final String? mail;
  final Map<String, String> cookies;

  const UserSession({
    required this.name,
    this.mail,
    this.cookies = const {},
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => _$UserSessionFromJson(json);

  Map<String, dynamic> toJson() => _$UserSessionToJson(this);
}

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<UserSession> login({
    required String name,
    required String password,
    bool persistent = false,
  }) async {
    final pageResponse = await _dio.get<String>(
      '/user/login',
      options: Options(responseType: ResponseType.plain),
    );

    final html = pageResponse.data ?? '';
    final formBuildId = _extractFormValue(html, 'form_build_id');
    final formId = _extractFormValue(html, 'form_id');

    if (formBuildId == null || formId == null) {
      throw const AuthException('Failed to extract form tokens');
    }

    final formData = {
      'name': name,
      'pass': password,
      'form_build_id': formBuildId,
      'form_id': formId,
      'openid.return_to': '',
      'op': 'Войти',
    };

    if (persistent) {
      formData['persistent_login'] = 'on';
    }

    final response = await _dio.post<String>(
      '/user/login',
      data: formData,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    final cookies = <String, String>{};
    final setCookies = response.headers['set-cookie'];
    if (setCookies != null) {
      for (final cookie in setCookies) {
        final firstPart = cookie.split(';').first;
        final eqIndex = firstPart.indexOf('=');
        if (eqIndex > 0) {
          cookies[firstPart.substring(0, eqIndex).trim()] = firstPart.substring(eqIndex + 1).trim();
        }
      }
    }

    final responseHtml = response.data ?? '';
    if (responseHtml.contains('Неверное имя пользователя или пароль') ||
        responseHtml.contains('Sorry, unrecognized username or password')) {
      throw const AuthException('Invalid username or password');
    }

    if (cookies.isEmpty) {
      throw const AuthException('Login failed: no session cookies received');
    }

    return UserSession(
      name: name,
      cookies: cookies,
    );
  }

  Future<void> logout() async {
    await _dio.get<String>('/user/logout');
  }

  String? _extractFormValue(String html, String fieldName) {
    final tagRegex = RegExp(
      '<input[^>]*name="$fieldName"[^>]*>',
      caseSensitive: false,
    );
    final tagMatch = tagRegex.firstMatch(html);
    if (tagMatch == null) return null;
    final valueRegex = RegExp(r'value="([^"]*)"');
    final valueMatch = valueRegex.firstMatch(tagMatch.group(0)!);
    return valueMatch?.group(1);
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

/// Dio interceptor that detects 401 responses and attempts auto re-login.
///
/// On 401, it tries [AuthStateNotifier.tryAutoLogin] with stored credentials.
/// If successful, retries the original request; otherwise passes the error.
class SessionRefreshInterceptor extends Interceptor {
  final Ref _ref;
  Completer<bool>? _pendingRefresh;

  SessionRefreshInterceptor(this._ref);

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.path.contains('/user/login') ||
        err.requestOptions.extra['sessionRefreshed'] == true) {
      handler.next(err);
      return;
    }

    // If a refresh is already in progress, wait for it
    if (_pendingRefresh != null) {
      final success = await _pendingRefresh!.future;
      if (!success) {
        handler.next(err);
        return;
      }
      await _retryRequest(err.requestOptions, handler);
      return;
    }

    _pendingRefresh = Completer<bool>();
    try {
      final success = await _ref.read(authStateProvider.notifier).tryAutoLogin();
      _pendingRefresh!.complete(success);

      if (success) {
        await _retryRequest(err.requestOptions, handler);
      } else {
        handler.next(err);
      }
    } on Object catch (e) {
      _pendingRefresh!.complete(false);
      AppLogger().warning('Session refresh failed: $e', name: 'Auth', error: e);
      handler.next(err);
    } finally {
      _pendingRefresh = null;
    }
  }

  Future<void> _retryRequest(
    RequestOptions options,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final response = await _ref
          .read(dioProvider)
          .fetch<dynamic>(
            options.copyWith(
              headers: options.headers,
              extra: {...options.extra, 'sessionRefreshed': true},
            ),
          );
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } on Object catch (e) {
      handler.next(DioException(requestOptions: options, error: e));
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  ),
);

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Future<AuthStateData> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_kSessionNameKey);
      if (name == null || name.isEmpty) {
        return const AuthStateData();
      }
      final mail = prefs.getString(_kSessionMailKey);
      final secureStorage = ref.read(flutterSecureStorageProvider);
      final cookiesRaw = await secureStorage.read(key: _kSessionCookiesKey);
      final cookies = cookiesRaw != null && cookiesRaw.isNotEmpty
          ? Map<String, String>.from(Uri.splitQueryString(cookiesRaw))
          : <String, String>{};
      if (cookies.isEmpty) {
        return const AuthStateData();
      }
      return AuthStateData(
        isAuthenticated: true,
        session: UserSession(name: name, mail: mail, cookies: cookies),
      );
    } on Object catch (e) {
      AppLogger().warning(
        'Failed to restore session from storage: $e',
        name: 'Auth',
        error: e,
      );
      return const AuthStateData();
    }
  }

  Future<void> login(String name, String password, bool persistent) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            name: name,
            password: password,
            persistent: persistent,
          );
      await _saveSession(session);
      try {
        await _updateRememberedCredentials(
          name: name,
          password: password,
          persistent: persistent,
        );
      } on Object catch (e) {
        AppLogger().warning(
          'Remembered credentials save failed: $e',
          name: 'Auth',
          error: e,
        );
      }
      return AuthStateData(
        isAuthenticated: true,
        session: session,
      );
    });
  }

  Future<void> logout() async {
    try {
      await ref.read(authRepositoryProvider).logout();
    } on Object catch (e) {
      AppLogger().warning(
        'Logout API failed (proceeding with local cleanup): $e',
        name: 'Auth',
        error: e,
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSessionNameKey);
      await prefs.remove(_kSessionMailKey);
      final secureStorage = ref.read(flutterSecureStorageProvider);
      await secureStorage.delete(key: _kSessionCookiesKey);
    } on Object catch (e) {
      AppLogger().warning(
        'Local session cleanup failed: $e',
        name: 'Auth',
        error: e,
      );
    }
    state = const AsyncValue.data(AuthStateData());
  }

  void clearError() {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(error: null));
    } else if (state is AsyncError) {
      state = const AsyncValue.data(AuthStateData());
    }
  }

  Future<bool> tryAutoLogin() async {
    final secureStorage = ref.read(flutterSecureStorageProvider);
    String? username;
    String? password;
    try {
      username = await secureStorage.read(key: 'auth_username');
      password = await secureStorage.read(key: 'auth_password');
    } on Object catch (e) {
      AppLogger().warning('Failed to read stored credentials: $e', name: 'Auth', error: e);
      return false;
    }
    if (username == null || password == null || username.isEmpty || password.isEmpty) {
      return false;
    }
    try {
      final session = await ref
          .read(authRepositoryProvider)
          .login(
            name: username,
            password: password,
            persistent: true,
          );
      await _saveSession(session);
      state = AsyncValue.data(
        AuthStateData(
          isAuthenticated: true,
          session: session,
        ),
      );
      return true;
    } on Object catch (e) {
      AppLogger().warning('Auto-login failed: $e', name: 'Auth');
      state = const AsyncValue.data(AuthStateData());
      return false;
    }
  }

  Future<void> _saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionNameKey, session.name);
    if (session.mail != null) {
      await prefs.setString(_kSessionMailKey, session.mail!);
    } else {
      await prefs.remove(_kSessionMailKey);
    }
    final secureStorage = ref.read(flutterSecureStorageProvider);
    if (session.cookies.isEmpty) {
      await secureStorage.delete(key: _kSessionCookiesKey);
      return;
    }
    final encoded = session.cookies.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
    await secureStorage.write(key: _kSessionCookiesKey, value: encoded);
  }

  Future<void> _updateRememberedCredentials({
    required String name,
    required String password,
    required bool persistent,
  }) async {
    final secureStorage = ref.read(flutterSecureStorageProvider);
    if (persistent) {
      await secureStorage.write(key: 'auth_username', value: name);
      await secureStorage.write(key: 'auth_password', value: password);
      return;
    }

    await (
      secureStorage.delete(key: 'auth_username'),
      secureStorage.delete(key: 'auth_password'),
    ).wait;
  }
}

@freezed
abstract class AuthStateData with _$AuthStateData {
  const factory AuthStateData({
    @Default(false) bool isAuthenticated,
    UserSession? session,
    String? error,
    @Default(false) bool isLoading,
  }) = _AuthStateData;

  const AuthStateData._();
}
