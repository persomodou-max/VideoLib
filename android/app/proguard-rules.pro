# ── Flutter core ──────────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── media_kit / libmpv ────────────────────────────────────────────────────────
-keep class com.alexmercerind.** { *; }
-dontwarn com.alexmercerind.**

# ── SQLite / sqflite ──────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── permission_handler ────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ── screen_brightness ─────────────────────────────────────────────────────────
-keep class com.aaassseee.screenbrightness.** { *; }
-dontwarn com.aaassseee.screenbrightness.**

# ── path_provider ─────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── shared_preferences ────────────────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── Kotlin serialization ──────────────────────────────────────────────────────
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── General Android safety ────────────────────────────────────────────────────
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# ── Prevent stripping JNI-called methods ─────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}
