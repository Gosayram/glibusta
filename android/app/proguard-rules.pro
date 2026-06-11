# Flutter-specific ProGuard rules

# Keep Flutter wrapper classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Play Core deferred component classes (referenced by Flutter engine)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Keep Drift database classes
-keep class com.gosayram.glibusta.core.database.** { *; }

# Keep serialization models
-keep class **.freezed.** { *; }
-keep class **.g.dart { *; }

# Keep Sentry
-keep class io.sentry.** { *; }

# Keep background_downloader
-keep class com.gosayram.glibusta.** { *; }
