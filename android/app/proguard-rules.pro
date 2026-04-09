# Google ML Kit Text Recognition rules
-keep class com.google.mlkit.vision.text.** { *; }
-dontwarn com.google.mlkit.vision.text.**
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# ProGuard rules to preserve generic signatures (CRITICAL for GSON/TypeToken)
-keepattributes Signature, EnclosingMethod, InnerClasses

# GSON rules
-keep class com.google.gson.** { *; }
-keep class sun.misc.Unsafe { *; }
-keep class com.google.gson.stream.** { *; }

# Flutter Local Notifications rules
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# MyDuitGweh Custom Services (Notification Listener)
-keep class com.arch.myduitgweh.NotifListenerService { *; }
-keep class com.arch.myduitgweh.MainActivity { *; }

# Firebase & Google Services
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Keep timezone data if applicable
-keep class com.samuelgdj.flutter_timezone.** { *; }
