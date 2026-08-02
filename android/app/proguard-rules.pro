# android/app/proguard-rules.pro
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.auth.** { *; }
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keep class com.squareup.** { *; }

# Pour Hive
-keep class * extends com.hivedb.HiveObject { *; }
-keepclassmembers class * { @com.hivedb.HiveField <fields>; }