import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_member_entity.dart';
import '../../domain/entities/join_request_entity.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/repositories/community_repository.dart';
import '../models/community_model.dart';
import '../models/community_member_model.dart';
import '../models/join_request_model.dart';
import '../models/group_model.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  // ── Collection refs ─────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _communities =>
      _db.collection('communities');

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> _members(String communityId) =>
      _communities.doc(communityId).collection('members');

  CollectionReference<Map<String, dynamic>> _joinRequests(String communityId) =>
      _communities.doc(communityId).collection('joinRequests');

  CollectionReference<Map<String, dynamic>> _groupMessages(String groupId) =>
      _groups.doc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _groupMembers(String groupId) =>
      _groups.doc(groupId).collection('members');

  // ── createCommunity ─────────────────────────────────────────────────────────

  @override
  Future<CommunityEntity> createCommunity({
    required String name,
    required String description,
    required String createdBy,
    required String creatorName,
    required String? creatorAvatarUrl,
    String? imageUrl,
    bool isPublic = true,
  }) async {
    final communityRef = _communities.doc();
    final communityId = communityRef.id;
    final now = Timestamp.now();
    final inviteLink = _uuid.v4();

    // 1. Create the announcement group first
    final announcementGroupRef = _groups.doc();
    final announcementGroupId = announcementGroupRef.id;
    final groupInviteLink = _uuid.v4();

    final batch = _db.batch();

    // Announcement group document
    batch.set(announcementGroupRef, {
      'name': '$name Announcements',
      'description': 'Official announcements for $name',
      'imageUrl': imageUrl,
      'ownerId': createdBy,
      'adminIds': [createdBy],
      'memberIds': [createdBy],
      'activeMembers': [createdBy],
      'createdAt': now,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'lastMessageAt': now,
      'isPublic': false,
      'inviteLink': groupInviteLink,
      'pinnedMessageId': null,
      'whoCanSend': 'adminsOnly',
      'unreadCount': {createdBy: 0},
      'communityId': communityId,
      'isAnnouncementOnly': true,
    });

    // Announcement group owner member doc
    batch.set(
      _groupMembers(announcementGroupId).doc(createdBy),
      {
        'name': creatorName,
        'avatarUrl': creatorAvatarUrl,
        'role': 'owner',
        'joinedAt': now,
        'isOnline': true,
        'lastSeen': now,
        'muteUntil': null,
      },
    );

    // System message for announcement group
    final sysMsgRef = _groupMessages(announcementGroupId).doc();
    batch.set(sysMsgRef, {
      'senderId': createdBy,
      'senderName': creatorName,
      'senderAvatarUrl': creatorAvatarUrl,
      'text': '',
      'mediaUrls': [],
      'messageType': 'system',
      'createdAt': now,
      'isEdited': false,
      'deletedForAll': false,
      'deletedForMe': [],
      'seenBy': {},
      'deliveredTo': {},
      'reactions': {},
      'mentionedUserIds': [],
      'systemText': '$creatorName created the community',
    });

    // 2. Community document
    batch.set(communityRef, {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'announcementGroupId': announcementGroupId,
      'inviteLink': inviteLink,
      'isPublic': isPublic,
      'createdAt': now,
    });

    // 3. Creator as superAdmin in members subcollection
    batch.set(
      _members(communityId).doc(createdBy),
      {
        'role': 'superAdmin',
        'joinedAt': now,
        'userId': createdBy,
      },
    );

    await batch.commit();

    final snap = await communityRef.get();
    return CommunityModel.fromFirestore(snap).toEntity();
  }

  // ── updateCommunityInfo ─────────────────────────────────────────────────────

  @override
  Future<void> updateCommunityInfo({
    required String communityId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (updates.isEmpty) return;
    await _communities.doc(communityId).update(updates);
  }

  // ── deleteCommunity ─────────────────────────────────────────────────────────
  // Groups are DETACHED (communityId = null), NOT deleted.

  @override
  Future<void> deleteCommunity({
    required String communityId,
    required String actorId,
  }) async {
    // 1. Detach all groups belonging to this community
    final groupsSnap = await _groups
        .where('communityId', isEqualTo: communityId)
        .get();

    final detachBatch = _db.batch();
    for (final doc in groupsSnap.docs) {
      detachBatch.update(doc.reference, {
        'communityId': null,
        'isAnnouncementOnly': false,
      });
    }
    await detachBatch.commit();

    // 2. Delete joinRequests subcollection
    await _deleteSubcollection(_joinRequests(communityId));

    // 3. Delete members subcollection
    await _deleteSubcollection(_members(communityId));

    // 4. Delete community document
    await _communities.doc(communityId).delete();
  }

  // ── getCommunity ────────────────────────────────────────────────────────────

  @override
  Future<CommunityEntity?> getCommunity(String communityId) async {
    final snap = await _communities.doc(communityId).get();
    if (!snap.exists) return null;
    return CommunityModel.fromFirestore(snap).toEntity();
  }

  @override
  Future<CommunityEntity?> getCommunityByInviteLink(String inviteLink) async {
    final snap = await _communities
        .where('inviteLink', isEqualTo: inviteLink)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return CommunityModel.fromFirestore(snap.docs.first).toEntity();
  }

  // ── Streams ─────────────────────────────────────────────────────────────────

  @override
  Stream<List<CommunityEntity>> watchUserCommunities(String userId) {
    // We listen to the user's member docs across all communities.
    // Pattern: collectionGroup query on 'members' where userId == userId.
    return _db
        .collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((memberSnap) async {
      // For each member doc, load the parent community document.
      // IMPORTANT: We must filter to only community member docs.
      // collectionGroup('members') also returns groups/{id}/members docs,
      // but those don't have a 'userId' field so they won't match the query.
      // As an extra guard, we validate the parent path is under 'communities'.
      final futures = memberSnap.docs.map((memberDoc) async {
        final parentCollection = memberDoc.reference.parent;
        final communityRef = parentCollection.parent;

        // Validate this is communities/{communityId}/members/{userId}
        // and NOT groups/{groupId}/members/{userId}
        if (communityRef == null) return null;
        if (communityRef.parent.id != 'communities') return null;

        try {
          final communitySnap = await communityRef.get();
          if (!communitySnap.exists) return null;
          return CommunityModel.fromFirestore(communitySnap).toEntity();
        } catch (e) {
          debugPrint('[CommunityRepo] Error fetching community: $e');
          return null;
        }
      });
      final results = await Future.wait(futures);
      return results.whereType<CommunityEntity>().toList();
    });
  }

  @override
  Stream<List<GroupEntity>> watchCommunityGroups(String communityId) {
    return _groups
        .where('communityId', isEqualTo: communityId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GroupModel.fromFirestore(d).toEntity()).toList());
  }

  @override
  Stream<List<CommunityMemberEntity>> watchCommunityMembers(
      String communityId) {
    return _members(communityId).snapshots().map((snap) => snap.docs
        .map((d) => CommunityMemberModel.fromFirestore(d).toEntity())
        .toList());
  }

  @override
  Stream<List<JoinRequestEntity>> watchJoinRequests(String communityId) {
    return _joinRequests(communityId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => JoinRequestModel.fromFirestore(d, communityId).toEntity())
            .toList());
  }

  // ── joinCommunity (public) ──────────────────────────────────────────────────

  @override
  Future<void> joinCommunity({
    required String communityId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  }) async {
    final communitySnap = await _communities.doc(communityId).get();
    if (!communitySnap.exists) throw Exception('Community not found');
    final community = CommunityModel.fromFirestore(communitySnap).toEntity();

    final now = Timestamp.now();
    final batch = _db.batch();

    // Add user to community members subcollection
    batch.set(_members(communityId).doc(userId), {
      'role': 'member',
      'joinedAt': now,
      'userId': userId,
    });

    // Add user ONLY to the announcement group
    batch.update(_groups.doc(community.announcementGroupId), {
      'memberIds': FieldValue.arrayUnion([userId]),
      'activeMembers': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });
    batch.set(
      _groupMembers(community.announcementGroupId).doc(userId),
      {
        'name': userName,
        'avatarUrl': userAvatarUrl,
        'role': 'member',
        'joinedAt': now,
        'isOnline': true,
        'lastSeen': now,
        'muteUntil': null,
      },
    );

    await batch.commit();
  }

  // ── requestToJoinCommunity (private) ────────────────────────────────────────

  @override
  Future<void> requestToJoinCommunity({
    required String communityId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  }) async {
    final now = Timestamp.now();

    // 1. Write the join request document
    final requestRef = _joinRequests(communityId).doc();
    await requestRef.set({
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'requestedAt': now,
      'status': 'pending',
    });

    // 2. Notify the community superAdmin via FCM.
    //    The existing Cloud Function fires on notifications/{id} creation.
    try {
      final communitySnap = await _communities.doc(communityId).get();
      if (!communitySnap.exists) return;

      final communityData = communitySnap.data()!;
      final adminId = communityData['createdBy'] as String?;
      final communityName = communityData['name'] as String? ?? 'Community';

      if (adminId == null || adminId == userId) return; // don't notify yourself

      await _db.collection('notifications').add({
        'type': 'community_join_request',
        'toUserId': adminId,
        'fromUserId': userId,
        'communityId': communityId,
        'communityName': communityName,
        'requestId': requestRef.id,
        'text': '$userName wants to join $communityName',
        'createdAt': now,
        'read': false,
      });
    } catch (e) {
      debugPrint('[CommunityRepo] Failed to send join request notification: $e');
      // Non-fatal — join request itself was already written successfully
    }
  }

  // ── approveJoinRequest ──────────────────────────────────────────────────────

  @override
  Future<void> approveJoinRequest({
    required String communityId,
    required String requestId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
    required String actorId,
  }) async {
    final communitySnap = await _communities.doc(communityId).get();
    if (!communitySnap.exists) throw Exception('Community not found');
    final community = CommunityModel.fromFirestore(communitySnap).toEntity();

    final now = Timestamp.now();
    final batch = _db.batch();

    // Update join request status
    batch.update(_joinRequests(communityId).doc(requestId), {
      'status': 'approved',
    });

    // Add to community members
    batch.set(_members(communityId).doc(userId), {
      'role': 'member',
      'joinedAt': now,
      'userId': userId,
    });

    // Add to announcement group ONLY
    batch.update(_groups.doc(community.announcementGroupId), {
      'memberIds': FieldValue.arrayUnion([userId]),
      'activeMembers': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });
    batch.set(
      _groupMembers(community.announcementGroupId).doc(userId),
      {
        'name': userName,
        'avatarUrl': userAvatarUrl,
        'role': 'member',
        'joinedAt': now,
        'isOnline': false,
        'lastSeen': null,
        'muteUntil': null,
      },
    );

    await batch.commit();
  }

  // ── denyJoinRequest ─────────────────────────────────────────────────────────

  @override
  Future<void> denyJoinRequest({
    required String communityId,
    required String requestId,
    required String actorId,
  }) async {
    await _joinRequests(communityId)
        .doc(requestId)
        .update({'status': 'denied'});
  }

  // ── leaveCommunity ──────────────────────────────────────────────────────────

  @override
  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  }) async {
    final communitySnap = await _communities.doc(communityId).get();
    if (!communitySnap.exists) return;
    final community = CommunityModel.fromFirestore(communitySnap).toEntity();

    final batch = _db.batch();

    // Remove from community members subcollection
    batch.delete(_members(communityId).doc(userId));

    // Remove from announcement group
    batch.update(_groups.doc(community.announcementGroupId), {
      'memberIds': FieldValue.arrayRemove([userId]),
      'activeMembers': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
    });
    batch.delete(_groupMembers(community.announcementGroupId).doc(userId));

    await batch.commit();

    // Also remove user from all community groups (best-effort, not in the same batch)
    final groupsSnap = await _groups
        .where('communityId', isEqualTo: communityId)
        .get();
    for (final groupDoc in groupsSnap.docs) {
      final memberIds =
          List<String>.from(groupDoc.data()['memberIds'] ?? []);
      if (memberIds.contains(userId)) {
        final b = _db.batch();
        b.update(groupDoc.reference, {
          'memberIds': FieldValue.arrayRemove([userId]),
          'activeMembers': FieldValue.arrayRemove([userId]),
          'adminIds': FieldValue.arrayRemove([userId]),
        });
        b.delete(_groupMembers(groupDoc.id).doc(userId));
        await b.commit();
      }
    }
  }

  // ── Member Management ───────────────────────────────────────────────────────

  @override
  Future<void> removeCommunityMember({
    required String communityId,
    required String targetUserId,
    required String actorId,
  }) async {
    await leaveCommunity(communityId: communityId, userId: targetUserId);
  }

  @override
  Future<void> promoteToCommunityAdmin({
    required String communityId,
    required String targetUserId,
    required String actorId,
  }) async {
    await _members(communityId).doc(targetUserId).update({'role': 'admin'});
    // Also promote in announcement group if they are a member
    final announcementGroupId = await _getAnnouncementGroupId(communityId);
    if (announcementGroupId != null) {
      await _groups.doc(announcementGroupId).update({
        'adminIds': FieldValue.arrayUnion([targetUserId]),
      });
    }
  }

  @override
  Future<void> demoteFromCommunityAdmin({
    required String communityId,
    required String targetUserId,
    required String actorId,
  }) async {
    await _members(communityId).doc(targetUserId).update({'role': 'member'});
    final announcementGroupId = await _getAnnouncementGroupId(communityId);
    if (announcementGroupId != null) {
      await _groups.doc(announcementGroupId).update({
        'adminIds': FieldValue.arrayRemove([targetUserId]),
      });
    }
  }

  @override
  Future<CommunityMemberEntity?> getMember({
    required String communityId,
    required String userId,
  }) async {
    final snap = await _members(communityId).doc(userId).get();
    if (!snap.exists) return null;
    return CommunityMemberModel.fromFirestore(snap).toEntity();
  }

  // ── Group Management ────────────────────────────────────────────────────────

  @override
  Future<GroupEntity> createGroupInCommunity({
    required String communityId,
    required String name,
    required String description,
    required String ownerId,
    required String ownerName,
    required String? ownerAvatarUrl,
    String? imageUrl,
    bool isAnnouncementOnly = false,
  }) async {
    final groupRef = _groups.doc();
    final groupId = groupRef.id;
    final now = Timestamp.now();
    final inviteLink = _uuid.v4();

    final batch = _db.batch();

    batch.set(groupRef, {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'adminIds': [ownerId],
      'memberIds': [ownerId],
      'createdAt': now,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'lastMessageAt': now,
      'isPublic': false,
      'inviteLink': inviteLink,
      'pinnedMessageId': null,
      'whoCanSend': isAnnouncementOnly ? 'adminsOnly' : 'everyone',
      'unreadCount': {ownerId: 0},
      'communityId': communityId,
      'isAnnouncementOnly': isAnnouncementOnly,
    });

    batch.set(
      _groupMembers(groupId).doc(ownerId),
      {
        'name': ownerName,
        'avatarUrl': ownerAvatarUrl,
        'role': 'owner',
        'joinedAt': now,
        'isOnline': true,
        'lastSeen': now,
        'muteUntil': null,
      },
    );

    final sysMsgRef = _groupMessages(groupId).doc();
    batch.set(sysMsgRef, {
      'senderId': ownerId,
      'senderName': ownerName,
      'senderAvatarUrl': ownerAvatarUrl,
      'text': '',
      'mediaUrls': [],
      'messageType': 'system',
      'createdAt': now,
      'isEdited': false,
      'deletedForAll': false,
      'deletedForMe': [],
      'seenBy': {},
      'deliveredTo': {},
      'reactions': {},
      'mentionedUserIds': [],
      'systemText': '$ownerName created the group',
    });

    await batch.commit();

    final snap = await groupRef.get();
    return GroupModel.fromFirestore(snap).toEntity();
  }

  @override
  Future<void> addGroupToCommunity({
    required String communityId,
    required String groupId,
  }) async {
    await _groups.doc(groupId).update({'communityId': communityId});
  }

  @override
  Future<void> removeGroupFromCommunity({required String groupId}) async {
    await _groups.doc(groupId).update({
      'communityId': null,
      'isAnnouncementOnly': false,
    });
  }

  // ── Invite Link ─────────────────────────────────────────────────────────────

  @override
  Future<String> regenerateCommunityInviteLink(String communityId) async {
    final newLink = _uuid.v4();
    await _communities.doc(communityId).update({'inviteLink': newLink});
    return newLink;
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<String?> _getAnnouncementGroupId(String communityId) async {
    final snap = await _communities.doc(communityId).get();
    if (!snap.exists) return null;
    return (snap.data()?['announcementGroupId'] as String?);
  }

  Future<void> _deleteSubcollection(
      CollectionReference<Map<String, dynamic>> ref) async {
    QuerySnapshot snap;
    do {
      snap = await ref.limit(400).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length >= 400);
  }
}
