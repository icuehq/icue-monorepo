# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.text.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
-dontwarn com.google.android.play.**

# AndroidX WorkManager & Room Database
-keep class androidx.work.impl.WorkDatabase_Impl { public <init>(); }
-keep class * extends androidx.work.impl.WorkDatabase { public <init>(); }
-keep class * extends androidx.work.ListenableWorker { public <init>(...); }
-keep class androidx.work.WorkManagerInitializer { *; }
-keep class * extends androidx.room.RoomDatabase { public <init>(); }
-dontwarn androidx.work.impl.**

# LiteRT & ML Kit
-keep class com.google.ai.edge.litert.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# iCue Face SDK
-keep class school.icue.face.core.** { *; }
