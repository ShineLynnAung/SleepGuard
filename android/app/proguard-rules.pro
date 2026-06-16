# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep SleepGuard native classes
-keep class com.sleepguard.app.** { *; }

# Keep MethodChannel classes
-keep class io.flutter.plugin.common.MethodChannel { *; }

# Keep Camera plugin
-keep class com.example.camera.** { *; }

# Keep sensors_plus
-keep class dev.fluttercommunity.plus.sensors.** { *; }

# Keep Play Core classes (needed by Flutter deferred components)
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
