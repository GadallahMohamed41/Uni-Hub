/// Enhanced Firestore operations for the new post features.
///
/// Provides methods to:
/// - Save privacy, feeling, and mentions with posts
/// - Send mention notifications
/// - Filter posts based on privacy settings
///
/// This file extends functionality WITHOUT modifying the existing
/// FirestoreService class.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../models/user_model.dart';

class PostEnhancementsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final PostEnhancementsService _instance =
      PostEnhancementsService._internal();
  factory PostEnhancementsService() => _instance;
  PostEnhancementsService._internal();

  /// After a post is created, update it with the enhanced fields.
  /// This is called after the existing createPost to add new fields
  /// without changing the existing createPost signature.
  Future<void> updatePostEnhancements({
    required String postId,
    required String privacy,
    String? feeling,
    List<String>? mentionedUserIds,
  }) async {
    final updates = <String, dynamic>{
      'privacy': privacy,
    };

    if (feeling != null && feeling.isNotEmpty) {
      updates['feeling'] = feeling;
    }

    if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
      updates['mentionedUserIds'] = mentionedUserIds;
    }

    await _firestore.collection('posts').doc(postId).update(updates);
  }

  /// Send mention notifications to all mentioned users.
  Future<void> sendMentionNotifications({
    required String postId,
    required String fromUserId,
    required String fromUserName,
    required String postText,
    required List<String> mentionedUserIds,
  }) async {
    if (mentionedUserIds.isEmpty) return;

    // Get sender data for the notification
    final senderData = await _getSenderData(fromUserId);

    for (final mentionedUid in mentionedUserIds) {
      if (mentionedUid == fromUserId) continue; // Don't notify self

      final notifId = 'post_mention_${mentionedUid}_${postId}_$fromUserId';
      await _firestore.collection('notifications').doc(notifId).set({
        'toUserId': mentionedUid,
        'fromUserId': fromUserId,
        'postId': postId,
        'type': 'post_mention',
        'text': '🔔 @$fromUserName mentioned you in a post',
        'createdAt': Timestamp.now(),
        'read': false,
        ...senderData,
      }, SetOptions(merge: true));
    }
  }

  /// Check if a post should be visible to the given viewer.
  /// Returns true if the post is visible.
  Future<bool> isPostVisibleTo({
    required String postOwnerId,
    required String viewerUserId,
    required String privacy,
  }) async {
    // Owner can always see their own posts
    if (postOwnerId == viewerUserId) return true;

    switch (privacy) {
      case 'public':
        return true;
      case 'friends_only':
        return await _areConnected(postOwnerId, viewerUserId);
      case 'private':
        return false;
      default:
        return true;
    }
  }

  /// Check if two users are connected (friends).
  Future<bool> _areConnected(String userId1, String userId2) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId1)
          .collection('connections')
          .doc(userId2)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('[PostEnhancementsService] _areConnected error: $e');
      return false;
    }
  }

  /// Get sender data (name, avatar) for notifications.
  Future<Map<String, dynamic>> _getSenderData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return {};
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] as String? ?? '').trim();
      final avatarUrl = (data['avatarUrl'] as String? ?? '').trim();
      return {
        if (name.isNotEmpty) 'senderName': name,
        if (avatarUrl.isNotEmpty) 'senderAvatarUrl': avatarUrl,
      };
    } catch (e) {
      return {};
    }
  }

  /// Get the list of connection IDs for a user (for privacy filtering).
  Future<Set<String>> getConnectionIds(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('connections')
          .get();
      return snapshot.docs.map((d) => d.id).toSet();
    } catch (e) {
      return {};
    }
  }

  /// Filter a list of posts based on privacy for the current viewer.
  /// This works client-side since Firestore doesn't support complex
  /// privacy queries with subcollection checks.
  Future<List<T>> filterPostsByPrivacy<T>({
    required List<T> posts,
    required String viewerUserId,
    required String Function(T) getOwnerId,
    required String Function(T) getPrivacy,
  }) async {
    // Pre-load viewer's connections for efficient filtering
    final connectionIds = await getConnectionIds(viewerUserId);

    return posts.where((post) {
      final ownerId = getOwnerId(post);
      final privacy = getPrivacy(post);

      // Owner always sees their own posts
      if (ownerId == viewerUserId) return true;

      switch (privacy) {
        case 'public':
          return true;
        case 'friends_only':
          return connectionIds.contains(ownerId);
        case 'private':
          return false;
        default:
          return true; // Backwards compatibility for posts without privacy
      }
    }).toList();
  }
}
