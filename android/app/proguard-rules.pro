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
# Cronet API
############################################

# `cronet-shared` is deliberately excluded because it duplicates the
# `org.chromium.net` namespace bundled by Play Services Cronet. The API keeps
# optional implementation references, which must not make R8 fail release
# builds when the Play Services provider is selected at runtime.
-dontwarn org.chromium.base.metrics.ScopedSysTraceEvent
-dontwarn org.chromium.net.httpflags.**
-dontwarn org.chromium.net.impl.CronetLogger**
-dontwarn org.chromium.net.impl.CronetManifest


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
