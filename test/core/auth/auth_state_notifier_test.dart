import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glibusta/core/auth/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockAuthRepository authRepository;
  late MockSecureStorage secureStorage;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    authRepository = MockAuthRepository();
    secureStorage = MockSecureStorage();
    when(
      () => secureStorage.read(
        key: any(named: 'key'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => secureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => secureStorage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => secureStorage.deleteAll()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        flutterSecureStorageProvider.overrideWithValue(secureStorage),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('clears remembered credentials when signing in without persistence', () async {
    when(
      () => authRepository.login(
        name: 'new-user',
        password: 'new-password',
      ),
    ).thenAnswer((_) async => const UserSession(name: 'new-user'));

    await container.read(authStateProvider.future);
    await container.read(authStateProvider.notifier).login('new-user', 'new-password', false);

    verify(() => secureStorage.delete(key: 'auth_username')).called(1);
    verify(() => secureStorage.delete(key: 'auth_password')).called(1);
  });

  test('stores credentials when signing in with persistence', () async {
    when(
      () => authRepository.login(
        name: 'remembered-user',
        password: 'remembered-password',
        persistent: true,
      ),
    ).thenAnswer((_) async => const UserSession(name: 'remembered-user'));

    await container.read(authStateProvider.future);
    await container
        .read(authStateProvider.notifier)
        .login('remembered-user', 'remembered-password', true);

    verify(
      () => secureStorage.write(
        key: 'auth_username',
        value: 'remembered-user',
      ),
    ).called(1);
    verify(
      () => secureStorage.write(
        key: 'auth_password',
        value: 'remembered-password',
      ),
    ).called(1);
  });
}
