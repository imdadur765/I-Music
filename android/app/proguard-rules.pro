# Flutter basic rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Play Core Split Install (Missing classes ke liye)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Audio service and media player
-keep class com.ryanheise.audioservice.** { *; }
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# Your app classes
-keep class com.example.i_music.** { *; }

# Riverpod state management
-keep class androidx.lifecycle.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-dontwarn kotlin.**