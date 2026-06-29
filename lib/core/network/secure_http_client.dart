import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class SecureHttpClient extends http.BaseClient {
  static http.Client? _client;

  /// تهيئة العميل الآمن باستخدام شهادة SSL المرفقة
  static Future<http.Client> getClient() async {
    if (_client != null) return _client!;

    try {
      // 1. تحميل ملف الشهادة من الـ Assets
      // ملاحظة: تأكد من وضع ملف الشهادة في: lib/assets/certs/server.pem
      // وتسجيله في ملف pubspec.yaml
      final sslCert = await rootBundle.load('lib/assets/certs/server.pem');
      
      // 2. إنشاء SecurityContext مخصص
      // نقوم بتعطيل Trusted Roots الافتراضية للجهاز لضمان قبول الشهادة المرفقة فقط
      final SecurityContext context = SecurityContext(withTrustedRoots: false);
      
      // 3. إضافة الشهادة كمرجع موثوق فريد للتطبيق
      context.setTrustedCertificatesBytes(sslCert.buffer.asUint8List());

      // 4. ربط الـ SecurityContext بـ HttpClient
      final HttpClient httpClient = HttpClient(context: context)
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          // رفض أي شهادة غير مطابقة للشهادة المحددة في الـ SecurityContext
          return false;
        };

      _client = IOClient(httpClient);
      return _client!;
    } catch (e) {
      // في حالة وجود خطأ (مثل عدم العثور على ملف الشهادة أثناء التطوير)،
      // نقوم بإنشاء عميل افتراضي مع طباعة تحذير أمني.
      // ملاحظة: في النسخة النهائية المرفوعة للمتجر، يجب إيقاف التطبيق وعدم الاستمرار في حالة فشل التهيئة.
      stderr.writeln('[SECURITY CRITICAL] Failed to initialize SSL Pinning: $e');
      _client = http.Client();
      return _client!;
    }
  }

  final http.Client _innerClient;
  SecureHttpClient(this._innerClient);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _innerClient.send(request);
  }
}
