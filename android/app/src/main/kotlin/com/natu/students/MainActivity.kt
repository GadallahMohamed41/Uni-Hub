package com.natu.students

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant
import android.webkit.WebView
import android.webkit.WebSettings
import android.os.Build
import android.os.Bundle
import android.content.Intent
import android.content.pm.ApplicationInfo

class MainActivity : FlutterFragmentActivity() {
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        validateIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        validateIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ✅ تمكين WebView وإعداداته بشكل آمن
        enableWebView()
    }
    
    private fun validateIntent(intent: Intent?) {
        if (intent == null) return
        
        // 1. صيانة ومنع حقن الـ Intents (Intent Hijacking) عبر التحقق من الـ Extras ومسحها إذا كانت ضخمة جداً
        try {
            val extras = intent.extras
            if (extras != null) {
                for (key in extras.keySet()) {
                    val value = extras.getCharSequence(key)
                    if (value != null && value.length > 2048) {
                        intent.removeExtra(key)
                    }
                }
            }
        } catch (e: Exception) {
            // تجاهل أي أخطاء في قراءة الـ keys
        }

        // 2. التحقق من صحة روابط الـ Deep Linking والـ App Links لمنع الـ Spoofing
        val data = intent.data
        if (data != null) {
            val scheme = data.scheme
            val host = data.host
            if (scheme != null && host != null) {
                if (scheme == "http" || scheme == "https") {
                    if (host != "university-connect-52779.web.app" && host != "projectv2.web.app") {
                        intent.data = null // إبطال الرابط المزور
                    }
                } else if (scheme != "myapp") {
                    intent.data = null // إبطال أي بروتوكول آخر غير مصرح به
                }
            }
        }
    }
    
    private fun enableWebView() {
        // ✅ تعطيل تفعيل الـ Debugging في وضع الـ Release لـ Google Play Store
        val isDebuggable = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            WebView.setWebContentsDebuggingEnabled(isDebuggable)
        }
        
        // ✅ إعدادات إضافية للـ WebView لحظر المحتوى المختلط غير المشفر
        val webView = WebView(this)
        val webSettings = webView.settings
        webSettings.javaScriptEnabled = true
        webSettings.domStorageEnabled = true
        webSettings.loadWithOverviewMode = true
        webSettings.useWideViewPort = true
        webSettings.builtInZoomControls = true
        webSettings.displayZoomControls = false
        webSettings.setSupportZoom(true)
        webSettings.defaultTextEncodingName = "utf-8"
        webSettings.loadsImagesAutomatically = true
        
        // منع تحميل الملفات والمواقع غير المشفرة (HTTP) داخل الـ WebView عند تصفح موقع آمن (HTTPS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            webSettings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
        }
        
        webView.clearCache(true)
        webView.clearHistory()
    }
}
