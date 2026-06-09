import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../http/dio_provider.dart';

class UserSession {
  final String name;
  final String? mail;
  final Map<String, String> cookies;

  const UserSession({
    required this.name,
    this.mail,
    this.cookies = const {},
  });
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

final authStateProvider = StateNotifierProvider<AuthState, AuthStateData>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthState(repo);
});

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
    bool? isLoading,
  }) {
    return AuthStateData(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      session: session ?? this.session,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthState extends StateNotifier<AuthStateData> {
  final AuthRepository _repo;

  AuthState(this._repo) : super(const AuthStateData());

  Future<void> login(String name, String password, bool persistent) async {
    state = state.copyWith(isLoading: true);
    try {
      final session = await _repo.login(name: name, password: password, persistent: persistent);
      state = state.copyWith(isAuthenticated: true, session: session, isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } on Object catch (_) {
      state = state.copyWith(error: 'Connection error', isLoading: false);
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } on Object catch (_) {}
    state = const AuthStateData();
  }

  void clearError() {
    state = state.copyWith();
  }
}
