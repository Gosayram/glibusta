sealed class AppFailure {
  const AppFailure();
}

class NetworkFailure extends AppFailure {
  final String? message;
  const NetworkFailure({this.message});
}

class NotFoundFailure extends AppFailure {
  final String? message;
  const NotFoundFailure({this.message});
}

class StorageFailure extends AppFailure {
  final String? message;
  const StorageFailure({this.message});
}

class ParseFailure extends AppFailure {
  final String? message;
  const ParseFailure({this.message});
}

class AuthFailure extends AppFailure {
  final String? message;
  const AuthFailure({this.message});
}

class UnknownFailure extends AppFailure {
  final String? message;
  const UnknownFailure({this.message});
}

String mapFailureToMessage(AppFailure failure) {
  return switch (failure) {
    NetworkFailure(:final message) => message ?? 'Ошибка сети',
    NotFoundFailure(:final message) => message ?? 'Не найдено',
    StorageFailure(:final message) => message ?? 'Ошибка хранилища',
    ParseFailure(:final message) => message ?? 'Ошибка парсинга',
    AuthFailure(:final message) => message ?? 'Ошибка авторизации',
    UnknownFailure(:final message) => message ?? 'Неизвестная ошибка',
  };
}
