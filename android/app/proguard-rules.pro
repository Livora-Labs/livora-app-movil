# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Hive & Storage
-keep class io.hive.** { *; }
-keep class com.github.theblueground.hive.** { *; }

# Sentry Flutter
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Firebase Messaging & Core
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Image Compression & Native Plugins
-keep class com.example.flutter_image_compress.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# Generic Kotlin & Coroutines
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Play Core (deferred components): el motor de Flutter referencia estas clases
# aunque la app no use deferred components. Sin esto R8 falla en release con
# "Missing class com.google.android.play.core.*".
-dontwarn com.google.android.play.core.**

