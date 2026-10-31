# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep HomeWidget and App Widget classes
-keep class es.antonborri.home_widget.** { *; }
-keep class com.example.subtracker.** { *; }
-dontwarn es.antonborri.home_widget.**
