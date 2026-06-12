import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../http/dio_provider.dart';
import '../logging/app_logger.dart';

part 'auth_repository.g.dart';

const _kSessionNameKey = 'auth_session_name';
const _kSessionMailKey = 'auth_session_mail';
const _kSessionCookiesKey = 'auth_session_cookies';

class UserSession {
  final String name;
  final String? mail;
  final Map<String, String> cookies;

  const UserSession({
    required this.name,
    this.mail,
    this.cookies = const {},
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'mail': mail,
    'cookies': cookies,
  };

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
    name: json['name'] as String,
    mail: json['mail'] as String?,
    cookies: Map<String, String>.from(json['cookies'] as Map? ?? {}),
  );
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
        final parts = cookie.split(';').first.split('=');
        if (parts.length >= 2) {
          cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
    }

    final responseHtml = response.data ?? '';
    if (responseHtml.contains('Неверное имя пользователя или пароль') ||
        responseHtml.contains('Sorry, unrecognized username or password')) {
      throw const AuthException('Invalid username or password');
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
    final regex = RegExp(
      '<input[^>]*name="$fieldName"[^>]*value="([^"]*)"',
      caseSensitive: false,
    );
    final match = regex.firstMatch(html);
    return match?.group(1);
  }
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return AuthRepository(dio);
});

@riverpod
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  Future<AuthStateData> build() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kSessionNameKey);
    if (name == null || name.isEmpty) {
      return const AuthStateData();
    }
    final mail = prefs.getString(_kSessionMailKey);
    final cookiesRaw = prefs.getString(_kSessionCookiesKey);
    final cookies = cookiesRaw != null && cookiesRaw.isNotEmpty
        ? Map<String, String>.from(
            Uri.splitQueryString(cookiesRaw),
          )
        : <String, String>{};
    return AuthStateData(
      isAuthenticated: true,
      session: UserSession(name: name, mail: mail, cookies: cookies),
    );
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSessionNameKey);
    await prefs.remove(_kSessionMailKey);
    await prefs.remove(_kSessionCookiesKey);
    state = const AsyncValue.data(AuthStateData());
  }

  void clearError() {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(clearError: true));
    }
  }

  Future<void> _saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSessionNameKey, session.name);
    if (session.mail != null) {
      await prefs.setString(_kSessionMailKey, session.mail!);
    }
    if (session.cookies.isNotEmpty) {
      final encoded = session.cookies.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      await prefs.setString(_kSessionCookiesKey, encoded);
    }
  }
}

class AuthStateData {
  final bool isAuthenticated;
  final UserSession? session;
  final String? error;
  final bool isLoading;

  const AuthStateData({
    this.isAuthenticated = false,
    this.session,
    this.error,
    this.isLoading = false,
  });

  AuthStateData copyWith({
    bool? isAuthenticated,
    UserSession? session,
    String? error,
    bool isLoading = false,
    bool clearError = false,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      session: session ?? this.session,
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading,
    );
  }
}
