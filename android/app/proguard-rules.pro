# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Supabase specific rules
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }

# Google Sign-In rules (still needed for Supabase OAuth)
-keep class com.google.android.gms.** { *; }

# Riverpod specific rules
-keep class com.riverpod.** { *; }

# Keep all model classes for JSON serialization
-keep class com.reva.app.reva_mobile_app.models.** { *; }

# General rules for reflection
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses