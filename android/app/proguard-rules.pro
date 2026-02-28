-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.core.** { *; }
-keep class androidx.work.** { *; }

# ExoPlayer / Media3 (used by video_player)
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# OkHttp/Okio if present via transitive deps
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Keep JSON models to avoid reflection stripping (safety)
-keep class **.model.** { *; }
