# Guava references optional J2ObjC stubs; not present on Android (AGP / R8 hint).
-dontwarn com.google.j2objc.annotations.ReflectionSupport
-dontwarn com.google.j2objc.annotations.RetainedWith

# google_places_autocomplete + Places SDK for Android (required for release / R8)
-keep class com.cuboid.google_places_autocomplete.** { *; }
-keep class com.google.android.libraries.places.** { *; }
-keepclassmembers class com.google.android.libraries.places.** { *; }
-dontwarn com.google.android.libraries.places.**
