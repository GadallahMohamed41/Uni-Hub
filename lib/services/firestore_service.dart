import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import 'storage_service.dart';
import '../models/comment_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _scheduleDocId(
    String universityKey,
    String departmentKey,
    String levelKey,
  ) {
    return '${universityKey}_${departmentKey}_$levelKey';
  }

  String _reactionNotificationId({
    required String toUserId,
    required String fromUserId,
    required String postId,
    required String type,
  }) {
    return '${toUserId}_${postId}_${type}_$fromUserId';
  }

  String _commentNotificationId({
    required String toUserId,
    required String postId,
    required String type,
    required String commentId,
  }) {
    return '${toUserId}_${postId}_${type}_$commentId';
  }

  Future<Map<String, dynamic>> _senderNotificationData(
      String fromUserId) async {
    final senderId = fromUserId.trim();
    if (senderId.isEmpty) {
      return const <String, dynamic>{};
    }

    final sender = await getUser(senderId);
    final senderName = (sender?.name ?? '').trim();
    final senderAvatarUrl = (sender?.avatarUrl ?? '').trim();

    return {
      if (senderName.isNotEmpty) 'senderName': senderName,
      if (senderAvatarUrl.isNotEmpty) 'senderAvatarUrl': senderAvatarUrl,
    };
  }

  //posts
  // هيظهر كل بوست حسب الاحدث
  Stream<List<PostModel>> getPostsStream({int? limit, String? currentUserId}) {
    var query = _firestore
        .collection('posts')
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true);
    if (limit != null) {
      query = query.limit(limit);
    }

    if (currentUserId == null || currentUserId.isEmpty) {
      return query.snapshots().map(
            (snapshot) => snapshot.docs
                .map((doc) => PostModel.fromFirestore(doc))
                .where((post) => post.privacyLevel == 'everyone')
                .toList(),
          );
    }

    return query.snapshots().asyncMap((snapshot) async {
      try {
        final connSnap = await _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('connections')
            .get();
        final connectionIds = connSnap.docs.map((d) => d.id).toSet();

        final posts = snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        return posts.where((post) {
          if (post.userId == currentUserId) return true;
          if (post.privacyLevel == 'everyone') return true;
          if (post.privacyLevel == 'friends') {
            return connectionIds.contains(post.userId);
          }
          return false; // 'only_me'
        }).toList();
      } catch (e) {
        // Fallback to public posts on error
        return snapshot.docs
            .map((doc) => PostModel.fromFirestore(doc))
            .where((post) => post.privacyLevel == 'everyone' || post.userId == currentUserId)
            .toList();
      }
    });
  }

  // جلب المنشورات المعلقة (للمشرفين)
  Stream<List<PostModel>> getPendingPostsStream() {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  /// Single-document fetch (any status). Used by deep links / notifications
  /// because [getPostsStream] only returns approved posts.
  Future<PostModel?> getPostById(String postId) async {
    final id = postId.trim();
    if (id.isEmpty) return null;
    try {
      final doc = await _firestore.collection('posts').doc(id).get();
      if (!doc.exists) return null;
      return PostModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[FirestoreService] getPostById failed for "$id": $e');
      rethrow;
    }
  }

  // تحديث حالة المنشور (قبول/رفض)
  Future<void> updatePostStatus(String postId, String status,
      {String? adminId}) async {
    await _firestore.collection('posts').doc(postId).update({'status': status});

    if (adminId != null) {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final ownerId = data['userId'] as String? ?? '';

      if (ownerId.isNotEmpty && ownerId != adminId) {
        final type = status == 'approved' ? 'post_approved' : 'post_rejected';
        final senderData = await _senderNotificationData(adminId);
        final postImageUrl = (data['imageUrl'] as String?)?.trim();

        final notifId = 'status_${postId}_$type';
        await _firestore.collection('notifications').doc(notifId).set({
          'toUserId': ownerId,
          'fromUserId': adminId,
          'postId': postId,
          'type': type,
          'text': data['text'],
          'createdAt': Timestamp.now(),
          'read': false,
          if (postImageUrl != null && postImageUrl.isNotEmpty)
            'imageUrl': postImageUrl,
          ...senderData,
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> deletePostDeep(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) {
      await deletePost(postId);
      return;
    }
    final data = doc.data() as Map<String, dynamic>;
    final urls = <String>[];
    final single = (data['imageUrl'] as String?)?.trim();
    if (single != null && single.isNotEmpty) urls.add(single);
    if (data['imageUrls'] is List) {
      for (final e in (data['imageUrls'] as List)) {
        final s = (e?.toString() ?? '').trim();
        if (s.isNotEmpty) urls.add(s);
      }
    }
    final videoUrl = (data['videoUrl'] as String?)?.trim();
    if (videoUrl != null && videoUrl.isNotEmpty) urls.add(videoUrl);

    final storage = StorageService();
    for (final u in urls) {
      try {
        await storage.deleteImage(u);
      } catch (_) {}
    }
    await deletePost(postId);
  }

  // بيظهر منشورات مستخدم معين (يظهر كل المنشورات الخاصة به بغض النظر عن الحالة)
  Stream<List<PostModel>> getUserPostsStream(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
  }

  // إنشاء منشور جديد
  Future<String> createPost({
    required String userId,
    required String userName,
    required String userBio,
    String? userAvatarUrl,
    required String text,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    String? repostOf,
    String? originalUserName,
    String? originalText,
    String? originalImageUrl,
    String status = 'pending',
    String privacyLevel = 'everyone',
    String? feeling,
    List<String>? mentionedUserIds,
  }) async {
    final normalizedUserAvatarUrl = (userAvatarUrl ?? '').trim();
    final normalizedOriginalImageUrl = (originalImageUrl ?? '').trim();
    final normalizedImageUrls = (imageUrls ?? const <String>[])
        .where((e) => e.trim().isNotEmpty)
        .toList();
    final normalizedImageUrlCandidate = (imageUrl ?? '').trim();
    final normalizedImageUrl = normalizedImageUrlCandidate.isNotEmpty
        ? normalizedImageUrlCandidate
        : (normalizedImageUrls.isNotEmpty ? normalizedImageUrls.first : null);
    final docRef = await _firestore.collection('posts').add({
      'userId': userId,
      'userName': userName,
      'userBio': userBio,
      'userAvatarUrl':
          normalizedUserAvatarUrl.isNotEmpty ? normalizedUserAvatarUrl : null,
      'text': text,
      'imageUrl': normalizedImageUrl,
      'imageUrls': normalizedImageUrls,
      'videoUrl': (videoUrl?.trim().isEmpty ?? true) ? null : videoUrl,
      'createdAt': Timestamp.now(),
      'likesCount': 0,
      'commentsCount': 0,
      'likedBy': [],
      'laughedBy': [],
      'supportedBy': [],
      'laughedCount': 0,
      'supportedCount': 0,
      'repostOf': repostOf,
      'originalUserName': originalUserName,
      'originalText': originalText,
      'originalImageUrl': normalizedOriginalImageUrl.isNotEmpty
          ? normalizedOriginalImageUrl
          : null,
      'status': status,
      'privacyLevel': privacyLevel,
      'feeling': feeling,
    });

    final senderData = await _senderNotificationData(userId);

    // Mention notification trigger
    if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
      for (final mentionedUid in mentionedUserIds) {
        if (mentionedUid == userId) continue;
        final notifId = 'post_mention_${mentionedUid}_${docRef.id}';
        await _firestore.collection('notifications').doc(notifId).set({
          'toUserId': mentionedUid,
          'fromUserId': userId,
          'postId': docRef.id,
          'type': 'post_mention',
          'text': '$userName mentioned you in a post',
          'createdAt': Timestamp.now(),
          'read': false,
          if (normalizedImageUrl != null && normalizedImageUrl.isNotEmpty)
            'imageUrl': normalizedImageUrl,
          ...senderData,
        }, SetOptions(merge: true));
      }
    }

    // بنقول  المشرفين إذا كان المنشور معلقاً
    if (status == 'pending') {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in admins.docs) {
        final toUserId = admin.id;
        final id = 'pending_${toUserId}_${userId}_${docRef.id}';
        // FCM / local notification payload must include at least: postId, type, toUserId routing.
        await _firestore.collection('notifications').doc(id).set({
          'toUserId': toUserId,
          'fromUserId': userId,
          'postId': docRef.id,
          'type': 'post_pending',
          'text': text,
          'createdAt': Timestamp.now(),
          'read': false,
          ...senderData,
        }, SetOptions(merge: true));
      }
    }
    return docRef.id;
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'read': true,
    });
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }

  Future<void> updateNotificationType(
    String notificationId,
    String type, {
    String? processedBy,
  }) async {
    await _firestore.collection('notifications').doc(notificationId).set({
      'type': type,
      'processedBy': processedBy,
    }, SetOptions(merge: true));
  }

  // User Blocking
  Future<void> blockUser({
    required String userId,
    DateTime? until,
  }) async {
    await _firestore.collection('users').doc(userId).update({
      'isBlocked': true,
      'blockedUntil': until != null ? Timestamp.fromDate(until) : null,
      'blockedAt': Timestamp.now(),
    });
  }

  Future<void> unblockUser(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isBlocked': false,
      'blockedUntil': null,
      'blockedAt': null,
    });
  }

  Future<String?> getPostStatus(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return (doc.data()?['status'] as String?)?.toString();
  }

  Stream<Map<String, dynamic>?> getScheduleMetaStream({
    required String universityKey,
    required String departmentKey,
    required String levelKey,
  }) {
    final id = _scheduleDocId(universityKey, departmentKey, levelKey);
    return _firestore.collection('schedules').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  Future<void> upsertScheduleMeta({
    required String universityKey,
    required String departmentKey,
    required String levelKey,
    required String imageUrl,
  }) async {
    final id = _scheduleDocId(universityKey, departmentKey, levelKey);
    await _firestore.collection('schedules').doc(id).set({
      'universityKey': universityKey,
      'departmentKey': departmentKey,
      'levelKey': levelKey,
      'imageUrl': imageUrl,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSchedule({
    required String universityKey,
    required String departmentKey,
    required String levelKey,
  }) async {
    final id = _scheduleDocId(universityKey, departmentKey, levelKey);
    final doc = await _firestore.collection('schedules').doc(id).get();
    final url = (doc.data()?['imageUrl'] as String?)?.trim();
    if (url != null && url.isNotEmpty) {
      try {
        await StorageService().deleteImage(url);
      } catch (_) {}
    }
    await _firestore.collection('schedules').doc(id).delete();
  }

  Future<void> cleanupPendingNotificationsForUser(String userId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('type', isEqualTo: 'post_pending')
        .limit(100)
        .get();
    if (snap.docs.isEmpty) return;

    for (final n in snap.docs) {
      final data = n.data();
      final postId = (data['postId'] as String?)?.trim();
      if (postId == null || postId.isEmpty) {
        continue;
      }
      final post = await _firestore.collection('posts').doc(postId).get();
      if (!post.exists) {
        try {
          await n.reference.delete();
        } catch (_) {}
        continue;
      }
      final status = (post.data()?['status'] as String?)?.trim();
      if (status == null || status == 'pending') continue;
      final newType = status == 'approved' ? 'post_approved' : 'post_rejected';
      await n.reference.set({
        'type': newType,
        'updatedAt': Timestamp.now(),
        'read': true,
      }, SetOptions(merge: true));
    }
  }

  Future<int> notifyScheduleUploaded({
    required String fromUserId,
    required String universityKey,
    required String departmentKey,
    required String levelKey,
    required String imageUrl,
  }) async {
    final senderData = await _senderNotificationData(fromUserId);
    final topic = 'schedules_${universityKey}_${departmentKey}_$levelKey';

    await _firestore.collection('broadcasts').add({
      'fromUserId': fromUserId,
      'type': 'schedule_uploaded',
      'universityKey': universityKey,
      'departmentKey': departmentKey,
      'levelKey': levelKey,
      'imageUrl': imageUrl,
      'targetTopic': topic,
      'createdAt': Timestamp.now(),
      ...senderData,
    });

    return 1;
  }

  // إنشاء إعادة نشر
  Future<String?> createRepost(
    String userId,
    String userName,
    String userBio,
    String? userAvatarUrl,
    String originalPostId, {
    String text = '',
  }) async {
    final originalDoc =
        await _firestore.collection('posts').doc(originalPostId).get();
    if (!originalDoc.exists) return null;
    final data = originalDoc.data()!;
    final originalOwnerId = (data['userId'] as String? ?? '').trim();
    final originalUserName = data['userName'] as String? ?? '';
    final originalText = data['text'] as String? ?? '';
    final originalImageUrl = (data['imageUrl'] as String?)?.trim();
    final originalImageUrls = (data['imageUrls'] is List)
        ? List<String>.from(data['imageUrls'] as List)
        : const <String>[];
    final normalizedOriginalImageUrls = originalImageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final senderData = await _senderNotificationData(userId);
    final newPostId = await createPost(
      userId: userId,
      userName: userName,
      userBio: userBio,
      userAvatarUrl: userAvatarUrl,
      text: text,
      imageUrl: null,
      imageUrls: null,
      repostOf: originalPostId,
      originalUserName: originalUserName,
      originalText: originalText,
      originalImageUrl:
          (originalImageUrl != null && originalImageUrl.isNotEmpty)
              ? originalImageUrl
              : (normalizedOriginalImageUrls.isNotEmpty
                  ? normalizedOriginalImageUrls.first
                  : null),
      status: 'approved',
    );

    if (originalOwnerId.isNotEmpty && originalOwnerId != userId) {
      final id = _reactionNotificationId(
        toUserId: originalOwnerId,
        fromUserId: userId,
        postId: originalPostId,
        type: 'repost',
      );
      await _firestore.collection('notifications').doc(id).set({
        'toUserId': originalOwnerId,
        'fromUserId': userId,
        'postId': originalPostId,
        'type': 'repost',
        'text': text,
        'createdAt': Timestamp.now(),
        'read': false,
        ...senderData,
      }, SetOptions(merge: true));
    }

    return newPostId;
  }

  // حذف منشور
  Future<void> deletePost(String postId) async {
    // حذف كل الريبوست المرتبطة أولاً (repost chain)
    final reposts = await _firestore
        .collection('posts')
        .where('repostOf', isEqualTo: postId)
        .get();
    for (final doc in reposts.docs) {
      await deletePost(doc.id);
    }

    // حذف كل التعليقات الخاصة بالمنشور
    final comments = await _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }

    // حذف المنشور نفسه
    await _firestore.collection('posts').doc(postId).delete();
  }

  // إعجاب/إلغاء إعجاب بمنشور
  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    final result = await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) {
        return {'notify': false, 'ownerId': ''};
      }
      final data = postDoc.data() as Map<String, dynamic>;
      final ownerId = data['userId'] as String? ?? '';
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final laughedBy = List<String>.from(data['laughedBy'] ?? []);
      final supportedBy = List<String>.from(data['supportedBy'] ?? []);

      final wasLiked = likedBy.contains(userId);
      likedBy.remove(userId);
      laughedBy.remove(userId);
      supportedBy.remove(userId);

      var didAdd = false;
      if (!wasLiked) {
        likedBy.add(userId);
        didAdd = true;
      }

      transaction.update(postRef, {
        'likedBy': likedBy,
        'laughedBy': laughedBy,
        'supportedBy': supportedBy,
        'likesCount': likedBy.length,
        'laughedCount': laughedBy.length,
        'supportedCount': supportedBy.length,
      });

      return {'notify': didAdd, 'ownerId': ownerId};
    });

    final ownerId = result['ownerId'] as String? ?? '';
    final notify = result['notify'] as bool? ?? false;
    if (!notify || ownerId.isEmpty || ownerId == userId) return;

    final senderData = await _senderNotificationData(userId);
    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'like',
    );
    String? postImageUrl;
    try {
      final post = await _firestore.collection('posts').doc(postId).get();
      postImageUrl = (post.data()?['imageUrl'] as String?)?.trim();
    } catch (_) {}
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'like',
      'createdAt': Timestamp.now(),
      'read': false,
      if (postImageUrl != null && postImageUrl.isNotEmpty)
        'imageUrl': postImageUrl,
      ...senderData,
    }, SetOptions(merge: true));
  }

  // تفاعل ضحك
  Future<void> toggleLaugh(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    final result = await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) {
        return {'notify': false, 'ownerId': ''};
      }
      final data = postDoc.data() as Map<String, dynamic>;
      final ownerId = data['userId'] as String? ?? '';
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final laughedBy = List<String>.from(data['laughedBy'] ?? []);
      final supportedBy = List<String>.from(data['supportedBy'] ?? []);

      final wasLaughed = laughedBy.contains(userId);
      likedBy.remove(userId);
      laughedBy.remove(userId);
      supportedBy.remove(userId);

      var didAdd = false;
      if (!wasLaughed) {
        laughedBy.add(userId);
        didAdd = true;
      }

      transaction.update(postRef, {
        'likedBy': likedBy,
        'laughedBy': laughedBy,
        'supportedBy': supportedBy,
        'likesCount': likedBy.length,
        'laughedCount': laughedBy.length,
        'supportedCount': supportedBy.length,
      });

      return {'notify': didAdd, 'ownerId': ownerId};
    });

    final ownerId = result['ownerId'] as String? ?? '';
    final notify = result['notify'] as bool? ?? false;
    if (!notify || ownerId.isEmpty || ownerId == userId) return;

    final senderData = await _senderNotificationData(userId);
    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'laugh',
    );
    String? postImageUrl;
    try {
      final post = await _firestore.collection('posts').doc(postId).get();
      postImageUrl = (post.data()?['imageUrl'] as String?)?.trim();
    } catch (_) {}
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'laugh',
      'createdAt': Timestamp.now(),
      'read': false,
      if (postImageUrl != null && postImageUrl.isNotEmpty)
        'imageUrl': postImageUrl,
      ...senderData,
    }, SetOptions(merge: true));
  }

  // تفاعل دعم
  Future<void> toggleSupport(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);

    final result = await _firestore.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) {
        return {'notify': false, 'ownerId': ''};
      }
      final data = postDoc.data() as Map<String, dynamic>;
      final ownerId = data['userId'] as String? ?? '';
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final laughedBy = List<String>.from(data['laughedBy'] ?? []);
      final supportedBy = List<String>.from(data['supportedBy'] ?? []);

      final wasSupported = supportedBy.contains(userId);
      likedBy.remove(userId);
      laughedBy.remove(userId);
      supportedBy.remove(userId);

      var didAdd = false;
      if (!wasSupported) {
        supportedBy.add(userId);
        didAdd = true;
      }

      transaction.update(postRef, {
        'likedBy': likedBy,
        'laughedBy': laughedBy,
        'supportedBy': supportedBy,
        'likesCount': likedBy.length,
        'laughedCount': laughedBy.length,
        'supportedCount': supportedBy.length,
      });

      return {'notify': didAdd, 'ownerId': ownerId};
    });

    final ownerId = result['ownerId'] as String? ?? '';
    final notify = result['notify'] as bool? ?? false;
    if (!notify || ownerId.isEmpty || ownerId == userId) return;

    final senderData = await _senderNotificationData(userId);
    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'support',
    );
    String? postImageUrl;
    try {
      final post = await _firestore.collection('posts').doc(postId).get();
      postImageUrl = (post.data()?['imageUrl'] as String?)?.trim();
    } catch (_) {}
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'support',
      'createdAt': Timestamp.now(),
      'read': false,
      if (postImageUrl != null && postImageUrl.isNotEmpty)
        'imageUrl': postImageUrl,
      ...senderData,
    }, SetOptions(merge: true));
  }

  // كومنت

  // جلب تعليقات منشور (التعليقات الرئيسية فقط)
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .where((c) => c.parentCommentId == null && !c.isDeleted)
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    });
  }

  Stream<List<CommentModel>> getPostCommentsThreadStream(String postId) {
    return _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .where((c) => !c.isDeleted)
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    });
  }

  // جلب ردود على تعليق معين
  Stream<List<CommentModel>> getCommentRepliesStream(String commentId) {
    return _firestore
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .where((c) => !c.isDeleted)
          .toList();
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    });
  }

  // إضافة تعليق
  Future<String> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String text,
    String? parentCommentId,
    List<String>? mentionedUserIds,
  }) async {
    final normalizedUserAvatarUrl = (userAvatarUrl ?? '').trim();
    final senderData = await _senderNotificationData(userId);
    final commentRef = _firestore.collection('comments').doc();
    final now = Timestamp.now();
    await commentRef.set({
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl':
          normalizedUserAvatarUrl.isNotEmpty ? normalizedUserAvatarUrl : null,
      'text': text,
      'createdAt': now,
      'updatedAt': now,
      'isDeleted': false,
      'parentCommentId': parentCommentId,
      'repliesCount': 0,
      'likedBy': [],
      'likesCount': 0,
      'mentionedUserIds': mentionedUserIds ?? [],
    });

    await _firestore.collection('posts').doc(postId).update({
      'commentsCount': FieldValue.increment(1),
    });

    if (parentCommentId == null) {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final ownerId = postDoc.data()?['userId'] as String? ?? '';
      final postImageUrl = (postDoc.data()?['imageUrl'] as String?)?.trim();
      if (ownerId.isNotEmpty && ownerId != userId) {
        final id = _commentNotificationId(
          toUserId: ownerId,
          postId: postId,
          type: 'comment',
          commentId: commentRef.id,
        );
        await _firestore.collection('notifications').doc(id).set({
          'toUserId': ownerId,
          'fromUserId': userId,
          'postId': postId,
          'type': 'comment',
          'commentId': commentRef.id,
          'text': text,
          'createdAt': Timestamp.now(),
          'read': false,
          if (postImageUrl != null && postImageUrl.isNotEmpty)
            'imageUrl': postImageUrl,
          ...senderData,
        }, SetOptions(merge: true));
      }
    } else {
      await _firestore.collection('comments').doc(parentCommentId).update({
        'repliesCount': FieldValue.increment(1),
      });

      final parentDoc =
          await _firestore.collection('comments').doc(parentCommentId).get();
      final parentOwnerId = parentDoc.data()?['userId'] as String? ?? '';
      String? postImageUrl;
      try {
        final post = await _firestore.collection('posts').doc(postId).get();
        postImageUrl = (post.data()?['imageUrl'] as String?)?.trim();
      } catch (_) {}
      if (parentOwnerId.isNotEmpty && parentOwnerId != userId) {
        final id = _commentNotificationId(
          toUserId: parentOwnerId,
          postId: postId,
          type: 'reply',
          commentId: commentRef.id,
        );
        await _firestore.collection('notifications').doc(id).set({
          'toUserId': parentOwnerId,
          'fromUserId': userId,
          'postId': postId,
          'type': 'reply',
          'commentId': commentRef.id,
          'parentCommentId': parentCommentId,
          'text': text,
          'createdAt': Timestamp.now(),
          'read': false,
          if (postImageUrl != null && postImageUrl.isNotEmpty)
            'imageUrl': postImageUrl,
          ...senderData,
        }, SetOptions(merge: true));
      }
    }

    // إنشاء إشعارات للمستخدمين المذكورين (@mention)
    final mentions = (mentionedUserIds ?? [])
        .where((uid) => uid.trim().isNotEmpty && uid != userId)
        .toSet();
    if (mentions.isNotEmpty) {
      String? postImageUrl;
      try {
        final post = await _firestore.collection('posts').doc(postId).get();
        postImageUrl = (post.data()?['imageUrl'] as String?)?.trim();
      } catch (_) {}
      for (final mentionedUid in mentions) {
        final notifId = '${mentionedUid}_${postId}_mention_${commentRef.id}';
        await _firestore.collection('notifications').doc(notifId).set({
          'toUserId': mentionedUid,
          'fromUserId': userId,
          'postId': postId,
          'type': 'mention',
          'commentId': commentRef.id,
          if (parentCommentId != null) 'parentCommentId': parentCommentId,
          'text': text,
          'createdAt': Timestamp.now(),
          'read': false,
          if (postImageUrl != null && postImageUrl.isNotEmpty)
            'imageUrl': postImageUrl,
          ...senderData,
        }, SetOptions(merge: true));
      }
    }

    return commentRef.id;
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((d) => {'id': d.id, ...d.data()})
          .where((data) {
            final type = data['type'] as String? ?? '';
            return type != 'chat_message' &&
                   type != 'group_message' &&
                   type != 'group_mention' &&
                   !type.toLowerCase().contains('request');
          })
          .toList();
      items.sort((a, b) {
        final at = a['createdAt'];
        final bt = b['createdAt'];
        final ad = at is Timestamp
            ? at.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bd = bt is Timestamp
            ? bt.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });
      return items;
    });
  }

  Stream<int> getUnreadNotificationsCountStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.where((d) {
              final type = d.data()['type'] as String? ?? '';
              return type != 'chat_message' &&
                     type != 'group_message' &&
                     type != 'group_mention' &&
                     !type.toLowerCase().contains('request');
            }).length);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    final snap = await _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return;

    var batch = _firestore.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      final type = doc.data()['type'] as String? ?? '';
      if (type == 'chat_message' || type == 'group_message' || type == 'group_mention') continue;

      batch.update(doc.reference, {'read': true});
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        writes = 0;
      }
    }
    if (writes > 0) {
      await batch.commit();
    }
  }

  // حذف تعليق
  Future<void> deleteComment(
    String commentId,
    String postId,
    String? parentCommentId,
  ) async {
    final commentRef = _firestore.collection('comments').doc(commentId);
    final batch = _firestore.batch();

    batch.update(commentRef, {
      'isDeleted': true,
      'text': '',
      'likedBy': [],
      'likesCount': 0,
      'mentionedUserIds': [],
      'updatedAt': Timestamp.now(),
    });

    batch.update(_firestore.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(-1),
    });

    if (parentCommentId != null) {
      batch.update(_firestore.collection('comments').doc(parentCommentId), {
        'repliesCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();

    try {
      final notificationsSnap = await _firestore
          .collection('notifications')
          .where('commentId', isEqualTo: commentId)
          .get();
      if (notificationsSnap.docs.isEmpty) return;
      var batch = _firestore.batch();
      var writes = 0;
      for (final doc in notificationsSnap.docs) {
        batch.delete(doc.reference);
        writes++;
        if (writes >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          writes = 0;
        }
      }
      if (writes > 0) {
        await batch.commit();
      }
    } catch (_) {}
  }

  // تعديل تعليق
  Future<void> updateComment(String commentId, String text) async {
    await _firestore.collection('comments').doc(commentId).update({
      'text': text,
      'updatedAt': Timestamp.now(),
    });
  }

  // إعجاب/إلغاء إعجاب بتعليق
  Future<void> toggleCommentLike(String commentId, String userId) async {
    final commentRef = _firestore.collection('comments').doc(commentId);

    final result = await _firestore.runTransaction((transaction) async {
      final commentDoc = await transaction.get(commentRef);
      if (!commentDoc.exists) {
        return {'notify': false, 'ownerId': '', 'postId': ''};
      }

      final data = commentDoc.data() as Map<String, dynamic>;
      final isDeleted = data['isDeleted'] as bool? ?? false;
      if (isDeleted) {
        return {'notify': false, 'ownerId': '', 'postId': ''};
      }
      final ownerId = data['userId'] as String? ?? '';
      final postId = data['postId'] as String? ?? '';
      final likedBy = List<String>.from(data['likedBy'] ?? []);

      bool didLike = false;
      if (likedBy.contains(userId)) {
        likedBy.remove(userId);
      } else {
        likedBy.add(userId);
        didLike = true;
      }

      transaction.update(commentRef, {
        'likedBy': likedBy,
        'likesCount': likedBy.length,
      });

      return {'notify': didLike, 'ownerId': ownerId, 'postId': postId};
    });

    final ownerId = result['ownerId'] as String;
    final postId = result['postId'] as String;
    final notify = result['notify'] as bool;

    if (notify && ownerId.isNotEmpty && ownerId != userId) {
      final senderData = await _senderNotificationData(userId);
      final id = '${ownerId}_${commentId}_like_$userId';
      await _firestore.collection('notifications').doc(id).set({
        'toUserId': ownerId,
        'fromUserId': userId,
        'postId': postId,
        'type': 'comment_like',
        'commentId': commentId,
        'createdAt': Timestamp.now(),
        'read': false,
        ...senderData,
      }, SetOptions(merge: true));
    }
  }

  // ================= المستخدمين =================

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('getUser error: $e');
      return null;
    }
  }

  // تحديث صورة المستخدم
  Future<void> updateUserAvatar(String userId, String avatarUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'avatarUrl': avatarUrl,
    });

    try {
      await _bulkUpdateAvatar(
        collection: 'posts',
        userId: userId,
        avatarUrl: avatarUrl,
      );
    } catch (_) {}

    try {
      await _bulkUpdateAvatar(
        collection: 'comments',
        userId: userId,
        avatarUrl: avatarUrl,
      );
    } catch (_) {}
  }

  Future<void> updateUserCvUrl(String userId, String cvUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'cvUrl': cvUrl,
    });
  }

  Future<void> updateUserCover(String userId, String coverUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'coverUrl': coverUrl,
    });
  }

  Future<void> updateUserCertificateUrl(
      String userId, String certificateUrl) async {
    await _firestore.collection('users').doc(userId).update({
      'certificateUrl': certificateUrl,
    });
  }

   Future<String> addUserCertificate({
    required String userId,
    required String name,
    required String description,  
    required String fileName,
    required String storagePath,
    required String url,
  }) async {
    final ref = await _firestore
        .collection('users')
        .doc(userId)
        .collection('certificates')
        .add({
      'name': name.trim(),
      'description': description.trim(), // إضافة الوصف
      'fileName': fileName.trim(),
      'storagePath': storagePath.trim(),
      'url': url.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  //  تعديل الدالة لجلب الـ description
  Future<List<Map<String, dynamic>>> listUserCertificates({
    required String userId,
    int limit = 20,
  }) async {
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('certificates')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': (data['name'] as String?)?.trim() ?? '',
        'description': (data['description'] as String?)?.trim() ?? '', // إضافة الوصف
        'fileName': (data['fileName'] as String?)?.trim() ?? '',
        'storagePath': (data['storagePath'] as String?)?.trim() ?? '',
        'url': (data['url'] as String?)?.trim() ?? '',
        'createdAt': data['createdAt'],
      };
    }).toList();
  }

  Future<List<Map<String, dynamic>>> listUserCertificatesForDisplay({
    required String userId,
    String? certificateUrlFromUserDoc,
    int limit = 20,
  }) async {
    // جلب الشهادات من subcollection فقط
    final snap = await _firestore
        .collection('users')
        .doc(userId)
        .collection('certificates')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    List<Map<String, dynamic>> list = snap.docs.map((d) {
      final data = d.data();
      return {
        'id': d.id,
        'name': (data['name'] as String?)?.trim() ?? '',
        'description': (data['description'] as String?)?.trim() ?? '', // إضافة الوصف
        'fileName': (data['fileName'] as String?)?.trim() ?? '',
        'storagePath': (data['storagePath'] as String?)?.trim() ?? '',
        'url': (data['url'] as String?)?.trim() ?? '',
        'createdAt': data['createdAt'],
      };
    }).toList();

    return list;
  }

  Future<void> deleteUserCertificate({
    required String userId,
    required String certificateId,
  }) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('certificates')
        .doc(certificateId)
        .delete();
  }

  Future<void> _bulkUpdateAvatar({
    required String collection,
    required String userId,
    required String avatarUrl,
  }) async {
    final snap = await _firestore
        .collection(collection)
        .where('userId', isEqualTo: userId)
        .get();
    if (snap.docs.isEmpty) return;

    var batch = _firestore.batch();
    var writes = 0;

    for (final doc in snap.docs) {
      batch.update(doc.reference, {'userAvatarUrl': avatarUrl});
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        writes = 0;
      }
    }

    if (writes > 0) {
      await batch.commit();
    }
  }

  // البحث عن مستخدمين
  Future<List<UserModel>> searchUsers(String query) async {
    final snapshot = await _firestore
        .collection('users')
        .where('name', isGreaterThanOrEqualTo: query)
        .where('name', isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // البحث عن مستخدمين في قائمة الأصدقاء (Connections)
  Future<List<UserModel>> searchConnections(String userId, String query) async {
    try {
      final lowerQuery = query.toLowerCase();

      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .get();
      if (snap.docs.isEmpty) return [];

      final ids = snap.docs.map((d) => d.id).toList();
      final users = <UserModel>[];
      const chunkSize = 10;

      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
            i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
        final querySnap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        users.addAll(querySnap.docs.map((doc) => UserModel.fromFirestore(doc)));
      }

      if (query.isEmpty) return users;

      return users
          .where((u) => u.name.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      return [];
    }
  }

  // للبحث عن مستخدمين بأكثر من ID (مثل حالة الإعجابات)
  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final users = <UserModel>[];
      const chunkSize = 10;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
            i, i + chunkSize > ids.length ? ids.length : i + chunkSize);
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        users.addAll(snap.docs.map((doc) => UserModel.fromFirestore(doc)));
      }
      return users;
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Follow / Unfollow System (Flow)
  // ═══════════════════════════════════════════════════════════════════════════
  /// متابعة مستخدم (Follow)
  Future<bool> followUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return false;
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;

    final followDocId = '${currentUserId}_$targetUserId';
    final followDocRef = _firestore.collection('followers').doc(followDocId);

    try {
      //  استخدام set مع merge: true
      await followDocRef.set({
        'followerId': currentUserId,
        'followingId': targetUserId,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // تحديث عدد المتابعين (مع تجاهل الخطأ)
      await _firestore.collection('users').doc(targetUserId).update({
        'followersCount': FieldValue.increment(1),
      }).catchError((e) => print(' Could not update followersCount: $e'));

      //  تحديث عدد اللي يتابعهم المستخدم الحالي (مع تجاهل الخطأ)
      await _firestore.collection('users').doc(currentUserId).update({
        'followingCount': FieldValue.increment(1),
      }).catchError((e) => print(' Could not update followingCount: $e'));

      print(' FollowUser success: $currentUserId -> $targetUserId');
      return true;
    } catch (e) {
      print(' FollowUser error: $e');
      return false;
    }
  }

  /// إلغاء متابعة مستخدم (Unfollow)
  Future<bool> unfollowUser(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return false;
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;

    final followDocId = '${currentUserId}_$targetUserId';
    final followDocRef = _firestore.collection('followers').doc(followDocId);

    try {
      await followDocRef.delete();

      await _firestore.collection('users').doc(targetUserId).update({
        'followersCount': FieldValue.increment(-1),
      });

      await _firestore.collection('users').doc(currentUserId).update({
        'followingCount': FieldValue.increment(-1),
      });

      print(' UnfollowUser success: $currentUserId -> $targetUserId');
      return true;
    } catch (e) {
      print(' UnfollowUser error: $e');
      return false;
    }
  }

  /// جلب عدد المتابعين لمستخدم معين (اللي بيتبعوه)
  Future<int> getFollowersCount(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final data = doc.data();
      return (data?['followersCount'] as int?) ?? 0;
    } catch (e) {
      print(' getFollowersCount error: $e');
      return 0;
    }
  }

  /// جلب عدد المستخدمين الذي يتابعهم هذا المستخدم (اللي هو بتابعهم)
  Future<int> getFollowingCount(String userId) async {
    try {
      final snap = await _firestore
          .collection('followers')
          .where('followerId', isEqualTo: userId)
          .get();
      return snap.docs.length;
    } catch (e) {
      print(' getFollowingCount error: $e');
      return 0;
    }
  }

  /// جلب عدد المتابعين (طريقة بديلة من خلال query)
  Future<int> getFollowersCountFromQuery(String userId) async {
    try {
      final snap = await _firestore
          .collection('followers')
          .where('followingId', isEqualTo: userId)
          .get();
      return snap.docs.length;
    } catch (e) {
      print(' getFollowersCountFromQuery error: $e');
      return 0;
    }
  }

  /// التحقق إذا كان المستخدم الحالي يتابع شخص معين
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    if (currentUserId == targetUserId) return false;
    if (currentUserId.isEmpty || targetUserId.isEmpty) return false;

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final doc =
          await _firestore.collection('followers').doc(followDocId).get();
      return doc.exists;
    } catch (e) {
      print(' isFollowing error: $e');
      return false;  
    }
  }

   Stream<int> streamFollowersCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['followersCount'] as int?) ?? 0);
  }

  /// ستريم مباشر لحالة المتابعة (يتغير تلقائياً)
  Stream<bool> streamIsFollowing(String currentUserId, String targetUserId) {
    if (currentUserId == targetUserId) {
      return Stream.value(false);
    }

    final followDocId = '${currentUserId}_$targetUserId';
    return _firestore
        .collection('followers')
        .doc(followDocId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// جلب قائمة المتابعين لمستخدم معين (اللي بيتبعوه)
  Future<List<UserModel>> getFollowersList(String userId) async {
    try {
      final snap = await _firestore
          .collection('followers')
          .where('followingId', isEqualTo: userId)
          .get();

      final followerIds =
          snap.docs.map((doc) => doc['followerId'] as String).toList();
      if (followerIds.isEmpty) return [];

      return await getUsersByIds(followerIds);
    } catch (e) {
      print(' getFollowersList error: $e');
      return [];
    }
  }

  /// جلب قائمة المستخدمين الذي يتابعهم هذا المستخدم (اللي هو بتابعهم)
  Future<List<UserModel>> getFollowingList(String userId) async {
    try {
      final snap = await _firestore
          .collection('followers')
          .where('followerId', isEqualTo: userId)
          .get();

      final followingIds =
          snap.docs.map((doc) => doc['followingId'] as String).toList();
      if (followingIds.isEmpty) return [];

      return await getUsersByIds(followingIds);
    } catch (e) {
      print(' getFollowingList error: $e');
      return [];
    }
  }

  /// تحديث الـ followingCount لمستخدم معين (للمزامنة اليدوية)
  Future<void> syncFollowingCount(String userId) async {
    try {
      final followingCount = await getFollowingCount(userId);
      await _firestore.collection('users').doc(userId).update({
        'followingCount': followingCount,
      });
      print(' syncFollowingCount: $userId -> $followingCount');
    } catch (e) {
      print(' syncFollowingCount error: $e');
    }
  }

  /// تحديث الـ followersCount لمستخدم معين (للمزامنة اليدوية)
  Future<void> syncFollowersCount(String userId) async {
    try {
      final followersCount = await getFollowersCountFromQuery(userId);
      await _firestore.collection('users').doc(userId).update({
        'followersCount': followersCount,
      });
      print(' syncFollowersCount: $userId -> $followersCount');
    } catch (e) {
      print(' syncFollowersCount error: $e');
    }
  }
}