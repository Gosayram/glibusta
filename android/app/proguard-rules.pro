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

# Keep background_downloader
-keep class com.gosayram.glibusta.** { *; }

# Flutter Rust Bridge — keep JNI native methods
-keep class com.gosayram.glibusta.** implements java.lang.reflect.InvocationHandler { *; }
-keep class com.gosayram.glibusta.** { <methods>; }
-keepclasseswithmembers class * {
    native <methods>;
}
