import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';
import 'package:project_test2/features/community/domain/repositories/group_join_request_repository.dart';
import 'package:project_test2/features/community/data/models/group_join_request_model.dart';

class GroupJoinRequestRepositoryImpl implements GroupJoinRequestRepository {
  final FirebaseFirestore _db;

  GroupJoinRequestRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('group_join_requests');

  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');

  CollectionReference<Map<String, dynamic>> _messages(String groupId) =>
      _groups.doc(groupId).collection('messages');

  @override
  Future<void> submitRequest({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String inviteToken,
  }) async {
    // Check if a pending request already exists to prevent duplicate spamming
    final existing = await _requests
        .where('groupId', isEqualTo: groupId)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    final docRef = _requests.doc();
    final model = GroupJoinRequestModel(
      requestId: docRef.id,
      groupId: groupId,
      groupName: groupName,
      groupImageUrl: groupImageUrl,
      userId: userId,
      userName: userName,
      userAvatarUrl: userAvatarUrl,
      requestedAt: DateTime.now(),
      status: GroupJoinRequestStatus.pending,
    );

    final batch = _db.batch();
    batch.set(docRef, model.toMap());

    // Send notifications to group admins
    final groupSnap = await _groups.doc(groupId).get();
    if (groupSnap.exists) {
      final groupData = groupSnap.data() ?? {};
      final adminIds = List<String>.from(groupData['adminIds'] ?? []);
      final now = Timestamp.now();

      for (final adminId in adminIds) {
        if (adminId == userId) continue;
        final notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'toUserId': adminId,
          'fromUserId': userId,
          'type': 'group_join_request',
          'groupId': groupId,
          'groupName': groupName,
          'requestId': docRef.id,
          'text': '$userName requested to join group $groupName',
          'createdAt': now,
          'read': false,
        });
      }
    }

    await batch.commit();
  }

  @override
  Stream<List<GroupJoinRequestEntity>> watchPendingRequests(String groupId) {
    return _requests
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'pending')
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => GroupJoinRequestModel.fromFirestore(doc).toEntity())
            .toList());
  }

  @override
  Future<void> approveRequest({
    required String requestId,
    required String groupId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
  }) async {
    final now = Timestamp.now();
    
    // Fetch group to see if it belongs to a community
    final groupSnap = await _groups.doc(groupId).get();
    String? communityId;
    if (groupSnap.exists) {
      communityId = groupSnap.data()?['communityId'] as String?;
    }
    
    final batch = _db.batch();

    // 1. Update request status to approved
    batch.update(_requests.doc(requestId), {
      'status': 'approved',
    });

    // 2. Add member to group document memberIds & activeMembers arrays & set unreadCount to 0
    batch.update(_groups.doc(groupId), {
      'memberIds': FieldValue.arrayUnion([userId]),
      'activeMembers': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });

    // 3. Add to members subcollection
    batch.set(_members(groupId).doc(userId), {
      'name': userName,
      'avatarUrl': userAvatarUrl,
      'role': 'member',
      'joinedAt': now,
      'isOnline': false,
      'lastSeen': null,
      'muteUntil': null,
    });

    // 4. Create system message inside group
    final actorId = FirebaseAuth.instance.currentUser?.uid ?? userId;
    final sysMsgRef = _messages(groupId).doc();
    batch.set(sysMsgRef, {
      'senderId': actorId,
      'senderName': userName,
      'senderAvatarUrl': userAvatarUrl,
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
      'systemText': '$userName joined the group via approval',
    });

    await batch.commit();

    // If group belongs to a community, attempt to add user to community members so it shows up in their dashboard.
    // We execute this in a separate write in a try-catch block so that if the group admin doesn't have
    // permissions on the community (e.g. not a community admin), the core group approval still succeeds.
    if (communityId != null && communityId.isNotEmpty) {
      try {
        await _db.collection('communities').doc(communityId).collection('members').doc(userId).set({
          'role': 'member',
          'joinedAt': now,
          'userId': userId,
        });
      } catch (e) {
        // Log the failure to write to community members but don't fail the group approval
        debugPrint('[GroupJoinRequestRepository] Non-fatal: Failed to add user to community members: $e');
      }
    }
  }

  @override
  Future<void> rejectRequest({required String requestId}) async {
    await _requests.doc(requestId).update({
      'status': 'rejected',
    });
  }

  @override
  Future<GroupJoinRequestEntity?> getRequest(String requestId) async {
    final doc = await _requests.doc(requestId).get();
    if (!doc.exists) return null;
    return GroupJoinRequestModel.fromFirestore(doc).toEntity();
  }
}
