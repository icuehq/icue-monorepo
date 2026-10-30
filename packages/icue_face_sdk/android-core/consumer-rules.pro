-keep class school.icue.face.core.** { *; }

# Keep LiteRT / TensorFlow Lite JNI and API classes
-keep class com.google.ai.edge.litert.** { *; }
-keep class org.tensorflow.lite.** { *; }

# Keep ML Kit Face Detection classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }

# Keep AndroidX WorkManager and Room database implementations
-keep class androidx.work.impl.WorkDatabase_Impl { public <init>(); }
-keep class * extends androidx.work.impl.WorkDatabase { public <init>(); }
-keep class * extends androidx.work.ListenableWorker { public <init>(...); }
-keep class androidx.work.WorkManagerInitializer { *; }
-keep class * extends androidx.room.RoomDatabase { public <init>(); }
