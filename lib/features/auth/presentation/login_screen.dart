import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/config/app_settings.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  static const _secureStorage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _persistent = true;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSavedCredentials());
  }

  Future<void> _loadSavedCredentials() async {
    final username = await _secureStorage.read(key: 'auth_username');
    final password = await _secureStorage.read(key: 'auth_password');
    if (username != null && mounted) {
      _nameController.text = username;
    }
    if (password != null && mounted) {
      _passwordController.text = password;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (prev, next) {
      final data = next.value;
      if (data != null && data.isAuthenticated && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вход выполнен успешно')),
        );
      }
      if (data != null && data.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data.error!)),
        );
        ref.read(authStateProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 32),
                  AutofillGroup(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          autofillHints: const [AutofillHints.username],
                          decoration: const InputDecoration(
                            labelText: 'Имя пользователя',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите имя пользователя';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: 'Пароль',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _persistent,
                    onChanged: (value) {
                      setState(() {
                        _persistent = value ?? true;
                      });
                    },
                    title: const Text('Запомнить меня'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: authAsync.isLoading ? null : _login,
                      child: authAsync.isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Войти'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () async {
                      final baseUrl = ref.read(appSettingsControllerProvider).baseUrl;
                      final base = baseUrl.endsWith('/')
                          ? baseUrl.substring(0, baseUrl.length - 1)
                          : baseUrl;
                      final uri = Uri.parse('$base/user/register');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text('Нет аккаунта? Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;

    unawaited(
      ref
          .read(authStateProvider.notifier)
          .login(
            _nameController.text.trim(),
            _passwordController.text,
            _persistent,
          )
          .then((_) {
            if (_persistent && mounted) {
              unawaited(
                _secureStorage.write(key: 'auth_username', value: _nameController.text.trim()),
              );
              unawaited(
                _secureStorage.write(key: 'auth_password', value: _passwordController.text),
              );
            }
          }),
    );
  }
}
