import 'app_failure.dart';

sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get value => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  AppFailure? get failure => switch (this) {
    Success() => null,
    Failure(:final failure) => failure,
  };

  AppResult<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success(:final value) => Success(transform(value)),
      Failure(:final failure) => Failure(failure),
    };
  }

  AppResult<T> flatMap(AppResult<T> Function(T value) transform) {
    return switch (this) {
      Success(:final value) => transform(value),
      Failure(:final failure) => Failure(failure),
    };
  }
}

class Success<T> extends AppResult<T> {
  @override
  final T value;
  const Success(this.value);
}

class Failure<T> extends AppResult<T> {
  @override
  final AppFailure failure;
  const Failure(this.failure);
}

Future<AppResult<T>> guardFuture<T>(Future<T> Function() operation) async {
  try {
    final result = await operation();
    return Success(result);
  } on AppFailure catch (e) {
    return Failure(e);
  } on Object catch (e) {
    return Failure(UnknownFailure(message: e.toString()));
  }
}
