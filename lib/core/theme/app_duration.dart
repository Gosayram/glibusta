class AppDuration {
  AppDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  static const Duration readerProgressSave = Duration(seconds: 5);

  static const Duration httpConnect = Duration(seconds: 10);
  static const Duration httpReceive = Duration(seconds: 30);
  static const Duration httpIdle = Duration.zero;
  static const Duration httpDownloadResponse = Duration(minutes: 10);
  static const Duration httpDownloadIdle = Duration(minutes: 5);

  static const Duration readerThemeTransition = Duration(milliseconds: 250);

  static const Duration autoThemeCheck = Duration(minutes: 1);
}
