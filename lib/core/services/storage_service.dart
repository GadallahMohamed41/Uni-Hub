import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final firebase_storage.FirebaseStorage _firebaseStorage =
      firebase_storage.FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();



  static Uint8List _normalizeImageBytesSync(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;
      final fixed = img.bakeOrientation(decoded);
      return Uint8List.fromList(img.encodeJpg(fixed, quality: 90));
    } catch (_) {
      return bytes;
    }
  }

  Future<Uint8List> _normalizeImageBytes(Uint8List bytes) async {
    return compute(_normalizeImageBytesSync, bytes);
  }

  // ========================= صور وبروفايلات =========================

  Future<String?> uploadProfileImageSigned(Uint8List bytes, String userId) async {
    try {
      final normalized = await _normalizeImageBytes(bytes);
      final storagePath = 'media/$userId/avatar_${_uuid.v4()}.jpg';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        normalized,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<String?> uploadCoverImageSigned(Uint8List bytes, String userId) async {
    try {
      final normalized = await _normalizeImageBytes(bytes);
      final storagePath = 'media/$userId/cover_${_uuid.v4()}.jpg';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        normalized,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading cover image: $e');
      return null;
    }
  }

  Future<String?> uploadPostImage(File imageFile, String userId) async {
    try {
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath = 'media/$userId/$fileName';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putFile(
        imageFile,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading post image: $e');
      return null;
    }
  }

  Future<String?> uploadPostVideoBytes(Uint8List bytes, String userId) async {
    try {
      final fileName = '${_uuid.v4()}.mp4';
      final storagePath = 'media/$userId/$fileName';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'video/mp4'),
      ).timeout(const Duration(seconds: 35));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading post video: $e');
      return null;
    }
  }

  Future<String?> uploadPostImageBytes(Uint8List bytes, String userId) async {
    try {
      final normalized = await _normalizeImageBytes(bytes);
      final fileName = '${_uuid.v4()}.jpg';
      final storagePath = 'media/$userId/$fileName';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        normalized,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading post image: $e');
      return null;
    }
  }

  Future<String?> uploadPostImageSigned(Uint8List bytes, String userId) async {
    return uploadPostImageBytes(bytes, userId);
  }

  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final storagePath = 'media/$userId/avatar_${_uuid.v4()}.jpg';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putFile(
        imageFile,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading profile image: $e');
      return null;
    }
  }

  Future<String?> uploadProfileImageBytes(Uint8List bytes, String userId) async {
    return uploadProfileImageSigned(bytes, userId);
  }

  // ========================= حذف الملفات =========================
  Future<void> deleteImage(String imageUrl) async {
    try {
      if (imageUrl.contains('firebasestorage.googleapis.com') || imageUrl.contains('firebase')) {
        final ref = _firebaseStorage.refFromURL(imageUrl);
        await ref.delete();
      }
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // ========================= الجدول الدراسي =========================
  Future<String?> uploadLectureSchedule(Uint8List bytes, String department) async {
    try {
      final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final storagePath = 'media/$uid/lectures_${department.replaceAll('/', '_')}.jpg';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
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
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'lectures/$universityKey/$departmentKey/${levelKey}_$ts.jpg';

    final ref = _firebaseStorage.ref().child(path);
    final uploadTask = ref.putData(
      bytes,
      firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
    );

    final snapshot = await uploadTask.timeout(const Duration(seconds: 20));
    return await snapshot.ref.getDownloadURL();
  }

  Future<String?> getScheduleUrl(
      String universityKey, String departmentKey, String levelKey) async {
    try {
      final path = 'lectures/$universityKey/$departmentKey/';
      final listResult = await _firebaseStorage.ref().child(path).listAll();

      if (listResult.items.isEmpty) return null;

      final latestItem = listResult.items.last;
      return await latestItem.getDownloadURL();
    } catch (e) {
      print('Error getting schedule URL from Firebase: $e');
      return null;
    }
  }

  // ========================= الحصول على رابط عام =========================
  String getPublicUrl(String storagePath) {
    if (storagePath.startsWith('http')) {
      return storagePath;
    }
    return storagePath;
  }

  // ========================= رفع ملف PDF =========================
  Future<String?> uploadPdfBytes(Uint8List bytes, String userId) async {
    try {
      final fileName = '${_uuid.v4()}.pdf';
      final storagePath = 'users/$userId/certificates/$fileName';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'application/pdf'),
      ).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading pdf: $e');
      return null;
    }
  }

  // ========================= رفع PDF كـ CV ثابت =========================
  Future<String?> uploadUserCv(Uint8List bytes, String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/cv_user_file.pdf';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'application/pdf'),
      ).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading user CV PDF: $e');
      return null;
    }
  }

  /// الحصول على رابط آخر PDF CV
  Future<String?> getUserCvUrl(String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/cv_user_file.pdf';
      return await _firebaseStorage.ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<bool> userCvExists(String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/cv_user_file.pdf';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.getMetadata();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// حذف ملف الـ CV من Firebase Storage
  Future<void> deleteUserCv(String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/cv_user_file.pdf';
      await _firebaseStorage.ref().child(storagePath).delete();
    } catch (e) {
      print('Error deleting user CV: $e');
      rethrow;
    }
  }

  // ========================= رفع PDF كـ Certificate ثابت =========================
  Future<String?> uploadUserCertificate(Uint8List bytes, String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/certificate_user_file.pdf';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'application/pdf'),
      ).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading user Certificate PDF: $e');
      return null;
    }
  }

  /// الحصول على رابط الـ Certificate
  Future<String?> getUserCertificateUrl(String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/certificate_user_file.pdf';
      return await _firebaseStorage.ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<bool> userCertificateExists(String userId) async {
    try {
      final storagePath = 'users/$userId/certificates/certificate_user_file.pdf';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.getMetadata();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> uploadUserCertificateItem({
    required Uint8List bytes,
    required String userId,
    required String fileName,
  }) async {
    try {
      final normalizedFileName = fileName.trim().isEmpty
          ? 'certificate_${_uuid.v4()}.pdf'
          : fileName.trim();
      final storagePath = 'users/$userId/certificates/$normalizedFileName';
      final ref = _firebaseStorage.ref().child(storagePath);
      await ref.putData(
        bytes,
        firebase_storage.SettableMetadata(contentType: 'application/pdf'),
      ).timeout(const Duration(seconds: 30));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading user certificate item: $e');
      return null;
    }
  }

  Future<String?> getUserCertificateItemUrl(String userId, String fileName) async {
    try {
      final storagePath = 'users/$userId/certificates/$fileName';
      return await _firebaseStorage.ref().child(storagePath).getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> listUserCertificateFileNames(String userId) async {
    try {
      final path = 'users/$userId/certificates';
      final listResult = await _firebaseStorage.ref().child(path).listAll();
      final pdfNames = listResult.items
          .map((item) => item.name)
          .where((name) => name.toLowerCase().endsWith('.pdf'))
          .where((name) => name.toLowerCase() != 'cv_user_file.pdf')
          .where((name) => name.toLowerCase() != 'certificate_user_file.pdf')
          .toList();
      pdfNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return pdfNames;
    } catch (_) {
      return <String>[];
    }
  }
}

extension StorageServiceFirebaseChatUploads on StorageService {
  Future<String?> uploadGroupImage(File imageFile, [String? userId]) async {
    try {
      final uid = userId ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final storagePath = 'media/$uid/group_avatars_${const Uuid().v4()}.jpg';
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(
        imageFile,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } on firebase_storage.FirebaseException catch (e) {
      print('Firebase Storage Error in uploadGroupImage: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      print('Generic Error in uploadGroupImage: $e');
      rethrow;
    }
  }

  Future<String?> uploadChatImage(File imageFile, [String? userId]) async {
    try {
      final uid = userId ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final storagePath = 'media/$uid/chat_images_${const Uuid().v4()}.jpg';
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(
        imageFile,
        firebase_storage.SettableMetadata(contentType: 'image/jpeg'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } on firebase_storage.FirebaseException catch (e) {
      print('Firebase Storage Error in uploadChatImage: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      print('Generic Error in uploadChatImage: $e');
      rethrow;
    }
  }

  Future<String?> uploadChatAudio(File audioFile, [String? userId]) async {
    try {
      final uid = userId ?? firebase_auth.FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
      final storagePath = 'media/$uid/chat_audio_${const Uuid().v4()}.m4a';
      final ref = firebase_storage.FirebaseStorage.instance.ref().child(storagePath);
      await ref.putFile(
        audioFile,
        firebase_storage.SettableMetadata(contentType: 'audio/m4a'),
      ).timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } on firebase_storage.FirebaseException catch (e) {
      print('Firebase Storage Error in uploadChatAudio: [${e.code}] ${e.message}');
      rethrow;
    } catch (e) {
      print('Generic Error in uploadChatAudio: $e');
      rethrow;
    }
  }
}
