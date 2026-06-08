sealed class AppFailure {
  final String? message;

  const AppFailure([this.message]);

  @override
  String toString() => '${runtimeType}: ${message ?? 'Unknown error'}';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message]);
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

final class CancelledFailure extends AppFailure {
  const CancelledFailure();
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message]);
}
