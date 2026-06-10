class AppDuration {
  AppDuration._();

  // Fast transitions
  static const Duration instant = Duration(milliseconds: 50);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Snackbar durations
  static const Duration snackbarShort = Duration(seconds: 2);
  static const Duration snackbarNormal = Duration(seconds: 3);
  static const Duration snackbarLong = Duration(seconds: 4);

  // Timer durations
  static const Duration readerHideDelay = Duration(seconds: 3);
  static const Duration readerProgressSave = Duration(seconds: 5);

  // Network timeouts
  static const Duration httpConnect = Duration(seconds: 10);
  static const Duration httpReceive = Duration(seconds: 30);
  static const Duration httpRequest = Duration(seconds: 30);

  // Auto-theme check
  static const Duration autoThemeCheck = Duration(minutes: 1);
}
