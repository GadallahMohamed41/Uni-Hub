import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

/// خدمة تخزين الصور باستخدام Supabase Storage (مجاني حتى 1GB)
/// بديل مجاني لـ Firebase Storage
/// 
/// ملاحظة: Firebase سيظل مستخدماً للـ Authentication و Firestore
class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  Future<void> _ensureSupabaseSession() async {
    if (_supabase.auth.currentSession != null) return;
    try {
      await _supabase.auth.signInAnonymously();
    } catch (e) {
      throw Exception(
        'Supabase auth failed (anonymous sign-in). Enable Anonymous Sign-ins in Supabase Dashboard > Authentication.',
      );
    }
    if (_supabase.auth.currentSession == null) {
      throw Exception(
        'Supabase session is not available (anonymous sign-in). Enable Anonymous Sign-ins in Supabase Dashboard > Authentication.',
      );
    }
  }

  Future<File> _bytesToTempFile(Uint8List bytes, String filename) async {
    final tmpPath = '${Directory.systemTemp.path}/$filename';
    final file = File(tmpPath);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Uint8List _normalizeImageBytes(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final fixed = img.bakeOrientation(decoded);
      return Uint8List.fromList(img.encodeJpg(fixed, quality: 90));
    } catch (_) {
      return bytes;
    }
  }

  Future<Map<String, dynamic>> _getSignedUpload(String userId, String kind) async {
    final res = await _supabase.functions.invoke('rapid-api', body: {
      'userId': userId,
      'kind': kind,
    });
    final data = res.data as Map;
    return {
      'path': data['path'] as String,
      'token': data['token'] as String,
    };
  }

  Future<String?> uploadProfileImageSigned(Uint8List bytes, String userId) async {
    try {
      if (kIsWeb) return null;
      final normalized = _normalizeImageBytes(bytes);
      final info = await _getSignedUpload(userId, 'post');
      final tmpFile = await _bytesToTempFile(normalized, 'avatar_${_uuid.v4()}.jpg');
      await _supabase.storage
          .from('images')
          .uploadToSignedUrl(info['path'] as String, info['token'] as String, tmpFile);
      return _supabase.storage.from('images').getPublicUrl(info['path'] as String);
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // رفع صورة منشور
  Future<String?> uploadPostImage(File imageFile, String userId) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath = 'posts/$userId/$fileName';
      final bytes = await imageFile.readAsBytes();
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // الحصول على رابط الصورة
      final imageUrl = _supabase.storage
          .from('images')
          .getPublicUrl(storagePath);

      return imageUrl;
    } catch (e) {
      print('Error uploading post image: $e');
      return null;
    }
  }

  Future<String?> uploadPostVideoBytes(Uint8List bytes, String userId) async {
    try {
      final info = await _getSignedUpload(userId, 'post');
      if (kIsWeb) {
        await _supabase.storage
            .from('images')
            .uploadBinary(
              info['path'] as String,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: 'video/mp4',
              ),
            );
      } else {
        final tmpFile = await _bytesToTempFile(bytes, '${_uuid.v4()}.mp4');
        await _supabase.storage
            .from('images')
            .uploadToSignedUrl(info['path'] as String, info['token'] as String, tmpFile);
      }
      final videoUrl = _supabase.storage.from('images').getPublicUrl(info['path'] as String);
      return videoUrl;
    } catch (e) {
      print('Error uploading post video: $e');
      return null;
    }
  }

  Future<String?> uploadPostImageBytes(Uint8List bytes, String userId) async {
    try {
      final normalized = _normalizeImageBytes(bytes);
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath = 'posts/$userId/$fileName';
      await _supabase.storage
          .from('images')
          .uploadBinary(
            storagePath,
            normalized,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );
      final imageUrl = _supabase.storage.from('images').getPublicUrl(storagePath);
      return imageUrl;
    } catch (e) {
      print('Error uploading post image: $e');
      return null;
    }
  }

  Future<String?> uploadPostImageSigned(Uint8List bytes, String userId) async {
    try {
      final info = await _getSignedUpload(userId, 'post');
      final normalized = _normalizeImageBytes(bytes);
      if (kIsWeb) {
        await _supabase.storage
            .from('images')
            .uploadBinary(
              info['path'] as String,
              normalized,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
      } else {
        final tmpFile = await _bytesToTempFile(normalized, '${_uuid.v4()}.jpg');
        await _supabase.storage
            .from('images')
            .uploadToSignedUrl(info['path'] as String, info['token'] as String, tmpFile);
      }
      final imageUrl = _supabase.storage.from('images').getPublicUrl(info['path'] as String);
      return imageUrl;
    } catch (e) { 
      
      print('Error uploading post image: $e');
    }
    return null;
  }

  // رفع صورة بروفايل
  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      await _ensureSupabaseSession();
      final storagePath = 'avatars/$userId.jpg';
      final bytes = await imageFile.readAsBytes();
      
      await _supabase.storage
          .from('images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '0',
              upsert: true,
            ),
          );

      // الحصول على رابط الصورة
      final imageUrl = _supabase.storage
          .from('images')
          .getPublicUrl(storagePath);

      return imageUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<String?> uploadProfileImageBytes(Uint8List bytes, String userId) async {
    try {
      await _ensureSupabaseSession();
      final storagePath = 'avatars/$userId.jpg';
      await _supabase.storage
          .from('images')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '0',
              upsert: true,
            ),
          );
      final imageUrl = _supabase.storage.from('images').getPublicUrl(storagePath);
      return imageUrl;
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  // حذف صورة
  Future<void> deleteImage(String imageUrl) async {
    try {
      // استخراج المسار من الرابط
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;
      
      // Supabase URL format: .../storage/v1/object/public/images/path/to/file
      // البحث عن 'images' في المسار
      final imagesIndex = pathSegments.indexOf('images');
      if (imagesIndex != -1 && imagesIndex < pathSegments.length - 1) {
        // أخذ كل المسار بعد 'images'
        final storagePath = pathSegments.sublist(imagesIndex + 1).join('/');
        await _supabase.storage.from('images').remove([storagePath]);
      } else {
        // محاولة بديلة: البحث عن 'public' ثم 'images'
        final publicIndex = pathSegments.indexOf('public');
        if (publicIndex != -1 && publicIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(publicIndex + 1).join('/');
          await _supabase.storage.from('images').remove([storagePath]);
        }
      }
    } catch (e) {
      print('Error deleting image: $e');
      // لا نرمي الخطأ لأن الحذف ليس حرجاً جداً
    }
  }

  // رفع صورة الجدول الدراسي
  Future<String?> uploadLectureSchedule(Uint8List bytes, String department) async {
    try {
      final fileName = 'lectures/$department.jpg';
      await _supabase.storage.from('images').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '0',
          upsert: true,
        ),
      );
      return _supabase.storage.from('images').getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading lecture schedule: $e');
      return null;
    }
  }
 
  Future<String> uploadLectureScheduleHierarchical(
    Uint8List bytes,
    String universityKey,
    String departmentKey,
    String levelKey,
  ) async {
    await _ensureSupabaseSession();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'lectures/$universityKey/$departmentKey/${levelKey}_$ts.jpg';
    await _supabase.storage.from('images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(
            cacheControl: '0',
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );
    return _supabase.storage.from('images').getPublicUrl(fileName);
  }
 
   String getScheduleUrl(String universityKey, String departmentKey, String levelKey) {
     final path = 'lectures/$universityKey/$departmentKey/$levelKey.jpg';
     return _supabase.storage.from('images').getPublicUrl(path);
   }

  // الحصول على رابط صورة في مسار معين
  String getPublicUrl(String storagePath) {
    return _supabase.storage.from('images').getPublicUrl(storagePath);
  }
}
