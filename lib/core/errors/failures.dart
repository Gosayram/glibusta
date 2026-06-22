sealed class AppFailure {
  final String? message;
  final StackTrace? stackTrace;

  const AppFailure([this.message, this.stackTrace]);

  @override
  String toString() => '$runtimeType: ${message ?? 'Unknown error'}';
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

final class SourceUnavailableFailure extends AppFailure {
  const SourceUnavailableFailure([super.message]);
}

final class ParserFailure extends AppFailure {
  const ParserFailure([super.message]);
}
