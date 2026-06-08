class AppFailure {
  final String? message;

  const AppFailure([this.message]);
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message]);
}

class SourceUnavailableFailure extends AppFailure {
  const SourceUnavailableFailure([super.message]);
}

class ParserFailure extends AppFailure {
  const ParserFailure([super.message]);
}

class DownloadFailure extends AppFailure {
  const DownloadFailure([super.message]);
}

class StorageFailure extends AppFailure {
  const StorageFailure([super.message]);
}

class CancelledFailure extends AppFailure {
  const CancelledFailure();
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([super.message]);
}