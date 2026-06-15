sealed class AppFailure {
  final String? message;
  final StackTrace? stackTrace;

  const AppFailure([this.message, this.stackTrace]);

  @override
  String toString() => '$runtimeType: ${message ?? 'Unknown error'}';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message]);
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure([super.message]);
}

sealed class BookOpenFailure extends AppFailure {
  const BookOpenFailure([super.message]);
}

final class BookMissingFailure extends BookOpenFailure {
  const BookMissingFailure([super.message]);
}

final class UnsupportedFormatFailure extends BookOpenFailure {
  const UnsupportedFormatFailure([super.message]);
}

final class ParserTimeoutFailure extends BookOpenFailure {
  const ParserTimeoutFailure([super.message]);
}

final class CacheCorruptedFailure extends BookOpenFailure {
  const CacheCorruptedFailure([super.message]);
}

final class InvalidEncodingFailure extends BookOpenFailure {
  const InvalidEncodingFailure([super.message]);
}

final class UnknownBookOpenFailure extends BookOpenFailure {
  const UnknownBookOpenFailure([super.message]);
}

final class SourceUnavailableFailure extends AppFailure {
  const SourceUnavailableFailure([super.message]);
}

final class ParserFailure extends AppFailure {
  const ParserFailure([super.message]);
}

final class DownloadFailure extends AppFailure {
  const DownloadFailure([super.message]);
}

final class StorageFailure extends AppFailure {
  const StorageFailure([super.message]);
}

final class AuthFailure extends AppFailure {
  const AuthFailure([super.message]);
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure();
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message, super.stackTrace]);
}
