# ProGuard/R8 Rules for production-grade hardening

# Firebase & Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class androidx.core.** { *; }
-keep class androidx.work.** { *; }

# Biometric local_auth plugin rules to prevent stripping biometric components
-keep class androidx.biometric.** { *; }
-keep class io.flutter.plugins.localauth.** { *; }

# Secure Storage rules to keep encryption and keystore classes intact
-keep class io.simplec.encryptor.** { *; }
-keep class io.flutter.plugins.securestorage.** { *; }
-keep class cn.pedant.SafePocket.** { *; }

# ExoPlayer / Media3 (used by video_player)
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# OkHttp / Okio / Network clients
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep reflection-targeted JSON models and serializable entities
-keep class **.model.** { *; }
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Preserve WebView settings and interfaces
-keepclassmembers class * extends android.webkit.WebViewClient {
    public void *(***);
}
-keepclassmembers class * extends android.webkit.WebChromeClient {
    public void *(***);
}