import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class PostsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<PostModel> _posts = [];
  final bool _isLoading = false;
  bool _isCreatingPost = false;
  String? _error;

  // Getters
  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isCreatingPost => _isCreatingPost;
  String? get error => _error;

  // الاستماع للمنشورات
  void listenToPosts() {
    _firestoreService.getPostsStream().listen(
      (posts) {
        _posts = posts;
        notifyListeners();
      },
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // إنشاء منشور جديد
  Future<bool> createPost({
    required String userId,
    required String userName,
    required String userBio,
    String? userAvatarUrl,
    required String text,
    List<Uint8List>? imageBytesList,
    Uint8List? videoBytes,
    String status = 'pending',
  }) async {
    _isCreatingPost = true;
    _error = null;
    notifyListeners();

    try {
      final images = (imageBytesList ?? const <Uint8List>[]).where((b) => b.isNotEmpty).toList();
      String? videoUrl;
      if (videoBytes != null && videoBytes.isNotEmpty) {
        videoUrl = await _storageService.uploadPostVideoBytes(videoBytes, userId);
        if (videoUrl == null) {
          _error = 'Failed to upload video. Check your connection.';
          _isCreatingPost = false;
          notifyListeners();
          return false;
        }
      }
      final List<String> imageUrls = [];
      for (final bytes in images) {
        final url = await _storageService.uploadPostImageSigned(bytes, userId);
        if (url == null) {
          _error = 'Failed to upload image. Check your connection.';
          _isCreatingPost = false;
          notifyListeners();
          return false;
        }
        imageUrls.add(url);
      }

      // إنشاء المنشور
      await _firestoreService.createPost(
        userId: userId,
        userName: userName,
        userBio: userBio,
        userAvatarUrl: userAvatarUrl,
        text: text,
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        imageUrls: imageUrls,
        videoUrl: videoUrl,
        status: status,
      );

      _isCreatingPost = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isCreatingPost = false;
      notifyListeners();
      return false;
    }
  }

  // إنشاء إعادة نشر
  Future<bool> createRepost({
    required String userId,
    required String userName,
    required String userBio,
    String? userAvatarUrl,
    required String originalPostId,
    String text = '',
  }) async {
    try {
      final id = await _firestoreService.createRepost(
        userId,
        userName,
        userBio,
        userAvatarUrl,
        originalPostId,
        text: text,
      );
      return id != null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // حذف منشور
  Future<bool> deletePost(String postId, List<String> imageUrls) async {
    try {
      // حذف الصورة من Storage
      for (final url in imageUrls) {
        if (url.trim().isEmpty) continue;
        await _storageService.deleteImage(url);
      }
      
      await _firestoreService.deletePost(postId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // إعجاب/إلغاء إعجاب
  Future<void> toggleLike(String postId, String userId) async {
    try {
      await _firestoreService.toggleLike(postId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // تفاعل ضحك 😊
  Future<void> toggleLaugh(String postId, String userId) async {
    try {
      await _firestoreService.toggleLaugh(postId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // تفاعل دعم ❤️
  Future<void> toggleSupport(String postId, String userId) async {
    try {
      await _firestoreService.toggleSupport(postId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // جلب المنشورات المعلقة
  Stream<List<PostModel>> getPendingPostsStream() {
    return _firestoreService.getPendingPostsStream();
  }

  // تحديث حالة المنشور
  Future<bool> updatePostStatus(String postId, String status) async {
    try {
      await _firestoreService.updatePostStatus(postId, status);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // جلب stream التعليقات
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _firestoreService.getCommentsStream(postId);
  }

  // جلب stream ردود على تعليق
  Stream<List<CommentModel>> getCommentRepliesStream(String commentId) {
    return _firestoreService.getCommentRepliesStream(commentId);
  }

  // إضافة تعليق
  Future<bool> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String text,
    String? parentCommentId,
  }) async {
    try {
      await _firestoreService.addComment(
        postId: postId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        text: text,
        parentCommentId: parentCommentId,
      );
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // حذف تعليق
  Future<bool> deleteComment(String commentId, String postId, String? parentCommentId) async {
    try {
      await _firestoreService.deleteComment(commentId, postId, parentCommentId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // تعديل تعليق
  Future<bool> updateComment(String commentId, String text) async {
    try {
      await _firestoreService.updateComment(commentId, text);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // إعجاب/إلغاء إعجاب بتعليق
  Future<void> toggleCommentLike(String commentId, String userId) async {
    try {
      await _firestoreService.toggleCommentLike(commentId, userId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
