import 'package:cloud_firestore/cloud_firestore.dart';
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

  //posts
  // هيظهر كل بوست حسب الاحدث
  Stream<List<PostModel>> getPostsStream() {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: 'approved')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => PostModel.fromFirestore(doc)).toList(),
        );
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

  // تحديث حالة المنشور (قبول/رفض)
  Future<void> updatePostStatus(String postId, String status) async {
    await _firestore.collection('posts').doc(postId).update({'status': status});
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
      'userAvatarUrl': normalizedUserAvatarUrl.isNotEmpty
          ? normalizedUserAvatarUrl
          : null,
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
    });
    // بنقول  المشرفين إذا كان المنشور معلقاً
    if (status == 'pending') {
      final admins = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'admin')
          .get();
      for (final admin in admins.docs) {
        final toUserId = admin.id;
        final id = 'pending_${toUserId}_${userId}_${docRef.id}';
        await _firestore.collection('notifications').doc(id).set({
          'toUserId': toUserId,
          'fromUserId': userId,
          'postId': docRef.id,
          'type': 'post_pending',
          'text': text,
          'createdAt': Timestamp.now(),
          'read': false,
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
      'updatedAt': Timestamp.now(),
      'read': true,
    }, SetOptions(merge: true));
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
    final usersSnap = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('universityKey', isEqualTo: universityKey)
        .where('departmentKey', isEqualTo: departmentKey)
        .where('levelKey', isEqualTo: levelKey)
        .get();

    if (usersSnap.docs.isEmpty) return 0;

    var batch = _firestore.batch();
    var writes = 0;
    for (final doc in usersSnap.docs) {
      final toUserId = doc.id;
      final ref = _firestore.collection('notifications').doc();
      batch.set(ref, {
        'toUserId': toUserId,
        'fromUserId': fromUserId,
        'type': 'schedule_uploaded',
        'universityKey': universityKey,
        'departmentKey': departmentKey,
        'levelKey': levelKey,
        'imageUrl': imageUrl,
        'createdAt': Timestamp.now(),
        'read': false,
      });
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
    return usersSnap.docs.length;
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
    //  المنشور الأصلي
    final originalDoc = await _firestore
        .collection('posts')
        .doc(originalPostId)
        .get();
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
        'createdAt': Timestamp.now(),
        'read': false,
      }, SetOptions(merge: true));
    }

    return newPostId;
  }

  // حذف منشور
  Future<void> deletePost(String postId) async {
    // حذف كل التعليقات أولاً
    final comments = await _firestore
        .collection('comments')
        .where('postId', isEqualTo: postId)
        .get();

    for (final doc in comments.docs) {
      await doc.reference.delete();
    }

    // حذف المنشور
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

    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'like',
    );
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'like',
      'createdAt': Timestamp.now(),
      'read': false,
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

    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'laugh',
    );
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'laugh',
      'createdAt': Timestamp.now(),
      'read': false,
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

    final id = _reactionNotificationId(
      toUserId: ownerId,
      fromUserId: userId,
      postId: postId,
      type: 'support',
    );
    await _firestore.collection('notifications').doc(id).set({
      'toUserId': ownerId,
      'fromUserId': userId,
      'postId': postId,
      'type': 'support',
      'createdAt': Timestamp.now(),
      'read': false,
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
              .where((c) => c.parentCommentId == null)
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
              .toList();
          items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return items;
        });
  }

  // إضافة تعليق
  Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String text,
    String? parentCommentId,
  }) async {
    final normalizedUserAvatarUrl = (userAvatarUrl ?? '').trim();
    final commentRef = _firestore.collection('comments').doc();
    await commentRef.set({
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': normalizedUserAvatarUrl.isNotEmpty
          ? normalizedUserAvatarUrl
          : null,
      'text': text,
      'createdAt': Timestamp.now(),
      'parentCommentId': parentCommentId,
      'repliesCount': 0,
      'likedBy': [],
      'likesCount': 0,
    });

    if (parentCommentId == null) {
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(1),
      });
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      final ownerId = postDoc.data()?['userId'] as String? ?? '';
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
        }, SetOptions(merge: true));
      }
    } else {
      await _firestore.collection('comments').doc(parentCommentId).update({
        'repliesCount': FieldValue.increment(1),
      });

      final parentDoc = await _firestore
          .collection('comments')
          .doc(parentCommentId)
          .get();
      final parentOwnerId = parentDoc.data()?['userId'] as String? ?? '';
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
        }, SetOptions(merge: true));
      }
    }
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((d) => {'id': d.id, ...d.data()})
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
        .map((s) => s.docs.length);
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
    // حذف كل الردود أولاً
    final replies = await _firestore
        .collection('comments')
        .where('parentCommentId', isEqualTo: commentId)
        .get();

    for (final doc in replies.docs) {
      await doc.reference.delete();
    }

    await _firestore.collection('comments').doc(commentId).delete();

    if (parentCommentId == null) {
      // تحديث عداد التعليقات في المنشور
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });
    } else {
      // تحديث عداد الردود في التعليق الأب
      await _firestore.collection('comments').doc(parentCommentId).update({
        'repliesCount': FieldValue.increment(-1),
      });
    }
  }

  // تعديل تعليق
  Future<void> updateComment(String commentId, String text) async {
    await _firestore.collection('comments').doc(commentId).update({
      'text': text,
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
      final id = '${ownerId}_${commentId}_like_$userId';
      await _firestore.collection('notifications').doc(id).set({
        'toUserId': ownerId,
        'fromUserId': userId,
        'postId': postId,
        'type': 'comment_like',
        'commentId': commentId,
        'createdAt': Timestamp.now(),
        'read': false,
      }, SetOptions(merge: true));
    }
  }

  // ================= المستخدمين =================

  // جلب بيانات مستخدم
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
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
}
