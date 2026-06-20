############################################
# Flutter Engine Embedding
############################################

-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class **.GeneratedPluginRegistrant { *; }


############################################
# JNI / Rust / flutter_rust_bridge
############################################

-keepclasseswithmembers class * {
    native <methods>;
}

-keep class com.gosayram.glibusta.MainActivity { *; }


############################################
# Kotlin Metadata
############################################

-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**


############################################
# Play Core deferred component
############################################

-dontwarn com.google.android.play.core.**


############################################
# Enum helpers
############################################

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}


############################################
# Crashlytics / mapping friendliness
############################################

-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile


############################################
# audio_service — keep MediaBrowserService
############################################

-keep class com.ryanheise.audioservice.** { *; }

############################################
# WebView JS bridge (if used in reader)
############################################

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
