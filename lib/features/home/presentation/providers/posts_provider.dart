import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/home/data/models/comment_model.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/core/services/storage_service.dart';

class PostsProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<PostModel> _posts = [];
  final bool _isLoading = false;
  bool _isCreatingPost = false;
  String? _error;
  StreamSubscription<List<PostModel>>? _postsSubscription;

  int _postsLimit = 15;
  bool _hasMorePosts = true;
  bool _isLoadingMorePosts = false;

  // Getters
  List<PostModel> get posts => _posts;
  bool get isLoading => _isLoading;
  bool get isCreatingPost => _isCreatingPost;
  String? get error => _error;
  int get postsLimit => _postsLimit;
  bool get hasMorePosts => _hasMorePosts;
  bool get isLoadingMorePosts => _isLoadingMorePosts;

  String? _currentUserId;
  int? _subscribedLimit;

  // Load cached posts from SharedPreferences
  Future<void> loadCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('cached_home_posts');
      if (cachedJson != null && _posts.isEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final cachedPosts = decoded.map((item) {
          final map = item['data'] as Map<String, dynamic>;
          final id = item['id'] as String;
          return PostModel.fromMap(map, id);
        }).toList();
        if (_posts.isEmpty && cachedPosts.isNotEmpty) {
          _posts = cachedPosts;
          notifyListeners();
          debugPrint('[PostsProvider] Loaded ${_posts.length} posts from local cache.');
        }
      }
    } catch (e) {
      debugPrint('[PostsProvider] Failed to load cached posts: $e');
    }
  }

  // Save posts to SharedPreferences
  Future<void> _cachePosts(List<PostModel> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> encoded = posts.map((post) {
        return {
          'id': post.id,
          'data': post.toJsonMap(),
        };
      }).toList();
      await prefs.setString('cached_home_posts', jsonEncode(encoded));
      debugPrint('[PostsProvider] Cached ${posts.length} posts locally.');
    } catch (e) {
      debugPrint('[PostsProvider] Failed to cache posts: $e');
    }
  }

  // الاستماع للمنشورات
  void listenToPosts({bool resetLimit = true, String? currentUserId, bool force = false}) {
    final targetUserId = currentUserId ?? _currentUserId;

    // Check if we can reuse the existing active subscription
    if (!force &&
        _postsSubscription != null &&
        _currentUserId == targetUserId &&
        _subscribedLimit == _postsLimit &&
        _posts.isNotEmpty) {
      debugPrint('[PostsProvider] Existing posts stream is active and up-to-date, skipping re-subscription.');
      return;
    }

    if (currentUserId != null) {
      _currentUserId = currentUserId;
    }
    if (resetLimit) {
      _postsLimit = 15;
      _hasMorePosts = true;
      _isLoadingMorePosts = false;
    }

    _subscribedLimit = _postsLimit;

    // Load cached posts instantly before fetching fresh ones
    if (_posts.isEmpty) {
      loadCachedPosts();
    }

    _postsSubscription?.cancel();
    _postsSubscription = _firestoreService.getPostsStream(limit: _postsLimit, currentUserId: _currentUserId).listen(
      (posts) {
        _posts = posts;
        _hasMorePosts = posts.length >= _postsLimit;
        _isLoadingMorePosts = false;
        notifyListeners();
        _cachePosts(posts); // Cache the fresh posts!
      },
      onError: (e) {
        _error = e.toString();
        _isLoadingMorePosts = false;
        notifyListeners();
      },
    );
  }

  Future<void> loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts) return;
    _isLoadingMorePosts = true;
    notifyListeners();

    _postsLimit += 15;
    listenToPosts(resetLimit: false);
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
    String privacyLevel = 'everyone',
    String? feeling,
    List<String>? mentionedUserIds,
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
        privacyLevel: privacyLevel,
        feeling: feeling,
        mentionedUserIds: mentionedUserIds,
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
    if (_isCreatingPost) return false;
    _isCreatingPost = true;
    _error = null;
    notifyListeners();

    try {
      final id = await _firestoreService.createRepost(
        userId,
        userName,
        userBio,
        userAvatarUrl,
        originalPostId,
        text: text,
      );
      _isCreatingPost = false;
      notifyListeners();
      return id != null;
    } catch (e) {
      _error = e.toString();
      _isCreatingPost = false;
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
  Future<bool> updatePostStatus(String postId, String status, {String? adminId}) async {
    try {
      await _firestoreService.updatePostStatus(postId, status, adminId: adminId);
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

  Stream<List<CommentModel>> getPostCommentsThreadStream(String postId) {
    return _firestoreService.getPostCommentsThreadStream(postId);
  }

  // جلب stream ردود على تعليق
  Stream<List<CommentModel>> getCommentRepliesStream(String commentId) {
    return _firestoreService.getCommentRepliesStream(commentId);
  }

  // إضافة تعليق
  Future<String?> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String text,
    String? parentCommentId,
    List<String>? mentionedUserIds,
  }) async {
    try {
      final id = await _firestoreService.addComment(
        postId: postId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        text: text,
        parentCommentId: parentCommentId,
        mentionedUserIds: mentionedUserIds,
      );
      return id;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
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

  void clearState() {
    _postsSubscription?.cancel();
    _postsSubscription = null;
    _subscribedLimit = null;
    _posts = [];
    _error = null;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isCreatingPost = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    super.dispose();
  }
}
