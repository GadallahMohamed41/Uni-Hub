import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';
import '../../domain/entities/group_message_entity.dart';
import '../../domain/repositories/group_repository.dart';
import '../models/group_member_model.dart';
import '../models/group_message_model.dart';
import '../models/group_model.dart';

class GroupRepositoryImpl implements GroupRepository {
  GroupRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  // ── Collection refs ────────────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _groups =>
      _db.collection('groups');

  CollectionReference<Map<String, dynamic>> _members(String groupId) =>
      _groups.doc(groupId).collection('members');

  CollectionReference<Map<String, dynamic>> _msgs(String groupId) =>
      _groups.doc(groupId).collection('messages');

  CollectionReference<Map<String, dynamic>> _typing(String groupId) =>
      _groups.doc(groupId).collection('typing');

  // ── Group CRUD ─────────────────────────────────────────────────────────────

  @override
  Future<GroupEntity> createGroup({
    required String name,
    required String description,
    required String ownerId,
    required String ownerName,
    required String? ownerAvatarUrl,
    required List<String> initialMemberIds,
    String? imageUrl,
    bool isPublic = false,
    WhoCanSend whoCanSend = WhoCanSend.everyone,
  }) async {
    final groupRef = _groups.doc();
    final groupId = groupRef.id;
    final now = Timestamp.now();
    final inviteLink = _uuid.v4();

    // Deduplicate — owner always a member
    final allMemberIds = ({ownerId, ...initialMemberIds}).toList();
    final adminIds = <String>[ownerId];

    final batch = _db.batch();

    // Create group document
    batch.set(groupRef, {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'adminIds': adminIds,
      'memberIds': allMemberIds,
      'activeMembers': allMemberIds,
      'createdAt': now,
      'lastMessage': '',
      'lastMessageSenderId': '',
      'lastMessageAt': now,
      'isPublic': isPublic,
      'inviteLink': inviteLink,
      'pinnedMessageId': null,
      'whoCanSend':
          whoCanSend == WhoCanSend.adminsOnly ? 'adminsOnly' : 'everyone',
      'unreadCount': {for (final id in allMemberIds) id: 0},
    });

    // Create member documents
    batch.set(
      _members(groupId).doc(ownerId),
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

    // System message
    final msgRef = _msgs(groupId).doc();
    batch.set(msgRef, {
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

    // Add initial members (outside batch to avoid 500-op limit)
    for (final memberId in initialMemberIds) {
      await _members(groupId).doc(memberId).set({
        'name': '',
        'avatarUrl': null,
        'role': 'member',
        'joinedAt': now,
        'isOnline': false,
        'lastSeen': null,
        'muteUntil': null,
      }, SetOptions(merge: true));
    }

    final snap = await groupRef.get();
    return GroupModel.fromFirestore(snap).toEntity();
  }

  @override
  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? imageUrl,
    WhoCanSend? whoCanSend,
    bool? isPublic,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (imageUrl != null) updates['imageUrl'] = imageUrl;
    if (whoCanSend != null) {
      updates['whoCanSend'] =
          whoCanSend == WhoCanSend.adminsOnly ? 'adminsOnly' : 'everyone';
    }
    if (isPublic != null) updates['isPublic'] = isPublic;
    if (updates.isEmpty) return;
    await _groups.doc(groupId).update(updates);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    // Delete messages subcollection in batches
    await _deleteCollection(_msgs(groupId));
    // Delete members subcollection
    await _deleteCollection(_members(groupId));
    // Delete typing subcollection
    await _deleteCollection(_typing(groupId));
    // Delete group document
    await _groups.doc(groupId).delete();
  }

  @override
  Future<GroupEntity?> getGroup(String groupId) async {
    final snap = await _groups.doc(groupId).get();
    if (!snap.exists) return null;
    return GroupModel.fromFirestore(snap).toEntity();
  }

  @override
  Future<GroupEntity?> getGroupByInviteLink(String inviteLink) async {
    final snap = await _groups
        .where('inviteLink', isEqualTo: inviteLink)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return GroupModel.fromFirestore(snap.docs.first).toEntity();
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  @override
  Stream<List<GroupEntity>> watchUserGroups(String userId) {
    return _groups
        .where('memberIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GroupModel.fromFirestore(d).toEntity()).toList());
  }

  @override
  Stream<GroupEntity?> watchGroup(String groupId) {
    return _groups.doc(groupId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GroupModel.fromFirestore(snap).toEntity();
    });
  }

  @override
  Stream<List<GroupMessageEntity>> watchMessages(String groupId,
      {int pageSize = 40}) {
    return _msgs(groupId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snap) {
      final messages = snap.docs
          .map((d) => GroupMessageModel.fromFirestore(d, groupId).toEntity())
          .toList();
      return messages.reversed.toList();
    });
  }

  @override
  Future<List<GroupMessageEntity>> loadMoreMessages(
    String groupId, {
    required String beforeMessageId,
    int pageSize = 30,
  }) async {
    final cursorDoc = await _msgs(groupId).doc(beforeMessageId).get();
    if (!cursorDoc.exists) return [];
    final snap = await _msgs(groupId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(cursorDoc)
        .limit(pageSize)
        .get();
    final messages = snap.docs
        .map((d) => GroupMessageModel.fromFirestore(d, groupId).toEntity())
        .toList();
    return messages.reversed.toList();
  }

  @override
  Stream<List<GroupMemberEntity>> watchMembers(String groupId) {
    return _members(groupId).snapshots().map((snap) =>
        snap.docs.map((d) => GroupMemberModel.fromFirestore(d).toEntity()).toList());
  }

  @override
  Stream<List<String>> watchTyping(String groupId) {
    return _typing(groupId).snapshots().map((snap) {
      final now = DateTime.now();
      return snap.docs.where((doc) {
        final data = doc.data();
        final isTyping = (data['isTyping'] as bool?) ?? false;
        if (!isTyping) return false;
        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
        if (updatedAt == null) return false;
        return now.difference(updatedAt).inSeconds < 6;
      }).map((doc) => doc.id).toList();
    });
  }

  // ── Members ────────────────────────────────────────────────────────────────

  @override
  Future<void> addMembers({
    required String groupId,
    required List<String> newMemberIds,
    required List<String> newMemberNames,
    required List<String?> newMemberAvatarUrls,
  }) async {
    final now = Timestamp.now();
    
    // Fetch group to see if it belongs to a community
    final groupSnap = await _groups.doc(groupId).get();
    String? communityId;
    if (groupSnap.exists) {
      communityId = groupSnap.data()?['communityId'] as String?;
    }
    
    final batch = _db.batch();

    // Update group memberIds and activeMembers arrays
    batch.update(_groups.doc(groupId), {
      'memberIds': FieldValue.arrayUnion(newMemberIds),
      'activeMembers': FieldValue.arrayUnion(newMemberIds),
      for (int i = 0; i < newMemberIds.length; i++)
        'unreadCount.${newMemberIds[i]}': 0,
    });

    for (int i = 0; i < newMemberIds.length; i++) {
      batch.set(_members(groupId).doc(newMemberIds[i]), {
        'name': newMemberNames[i],
        'avatarUrl': newMemberAvatarUrls[i],
        'role': 'member',
        'joinedAt': now,
        'isOnline': false,
        'lastSeen': null,
        'muteUntil': null,
      });
    }

    await batch.commit();

    // If group belongs to a community, attempt to add them to community members as well.
    // We execute this outside the main transaction in a try-catch block so that if the group admin doesn't have
    // permissions on the community (e.g. not a community admin), the core group member additions still succeed.
    if (communityId != null && communityId.isNotEmpty) {
      for (int i = 0; i < newMemberIds.length; i++) {
        try {
          await _db.collection('communities').doc(communityId).collection('members').doc(newMemberIds[i]).set({
            'role': 'member',
            'joinedAt': now,
            'userId': newMemberIds[i],
          });
        } catch (e) {
          debugPrint('[GroupRepository] Non-fatal: Failed to add user to community members: $e');
        }
      }
    }
  }

  @override
  Future<void> removeMember({
    required String groupId,
    required String targetUserId,
    required String actorId,
  }) async {
    // 1. Fetch target user's name
    String targetUserName = 'A member';
    try {
      final memberSnap = await _members(groupId).doc(targetUserId).get();
      if (memberSnap.exists) {
        targetUserName = (memberSnap.data()?['name'] as String?) ?? 'A member';
      } else {
        // Fallback to users collection
        final userSnap = await _db.collection('users').doc(targetUserId).get();
        if (userSnap.exists) {
          targetUserName = (userSnap.data()?['name'] as String?) ?? 'A member';
        }
      }
    } catch (e) {
      debugPrint('[GroupRepository] Failed to fetch member name for system message: $e');
    }

    if (targetUserName.trim().isEmpty) {
      targetUserName = 'A member';
    }

    final now = Timestamp.now();
    final systemText = actorId == targetUserId
        ? '$targetUserName left the group'
        : '$targetUserName was removed';

    final batch = _db.batch();

    // 2. Update group document (remove user from membership arrays and set last message info)
    batch.update(_groups.doc(groupId), {
      'memberIds': FieldValue.arrayRemove([targetUserId]),
      'activeMembers': FieldValue.arrayRemove([targetUserId]),
      'adminIds': FieldValue.arrayRemove([targetUserId]),
      'lastMessage': systemText,
      'lastMessageSenderId': 'system',
      'lastMessageAt': now,
    });

    // 3. Delete member document from group members sub-collection
    batch.delete(_members(groupId).doc(targetUserId));

    // 4. Create system message document in the group's messages sub-collection
    final msgRef = _msgs(groupId).doc();
    batch.set(msgRef, {
      'senderId': actorId,
      'senderName': 'System',
      'senderAvatarUrl': null,
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
      'systemText': systemText,
    });

    await batch.commit();

    // Delete typing indicator separately so if rules are not updated/deployed yet,
    // it fails gracefully without rolling back the main member deletion.
    try {
      await _typing(groupId).doc(targetUserId).delete();
    } catch (e) {
      debugPrint('[GroupRepository] Non-fatal: failed to delete typing indicator: $e');
    }

    // Auto-remove from community membership when leaving the announcement group
    try {
      final groupSnap = await _groups.doc(groupId).get();
      if (groupSnap.exists) {
        final data = groupSnap.data() ?? {};
        final isAnnouncement = (data['isAnnouncementOnly'] as bool?) == true;
        final communityId = data['communityId'] as String?;
        if (isAnnouncement && communityId != null && communityId.isNotEmpty) {
          // Delete from community members
          await _db
              .collection('communities')
              .doc(communityId)
              .collection('members')
              .doc(targetUserId)
              .delete();

          // Remove user from all other groups in this community
          final groupsSnap = await _groups
              .where('communityId', isEqualTo: communityId)
              .get();
          for (final groupDoc in groupsSnap.docs) {
            if (groupDoc.id == groupId) continue; // already handled by the main removeMember batch
            final memberIds = List<String>.from(groupDoc.data()['memberIds'] ?? []);
            if (memberIds.contains(targetUserId)) {
              final b = _db.batch();
              b.update(groupDoc.reference, {
                'memberIds': FieldValue.arrayRemove([targetUserId]),
                'activeMembers': FieldValue.arrayRemove([targetUserId]),
                'adminIds': FieldValue.arrayRemove([targetUserId]),
              });
              b.delete(_groups.doc(groupDoc.id).collection('members').doc(targetUserId));
              await b.commit();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[GroupRepository] Non-fatal: failed to remove community membership on group leave: $e');
    }
  }

  @override
  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
    required String actorId,
  }) async {
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'adminIds': FieldValue.arrayUnion([targetUserId]),
    });
    batch.update(_members(groupId).doc(targetUserId), {'role': 'admin'});
    await batch.commit();
  }

  @override
  Future<void> demoteFromAdmin({
    required String groupId,
    required String targetUserId,
    required String actorId,
  }) async {
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'adminIds': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(_members(groupId).doc(targetUserId), {'role': 'member'});
    await batch.commit();
  }

  @override
  Future<void> transferOwnership({
    required String groupId,
    required String newOwnerId,
    required String currentOwnerId,
  }) async {
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'ownerId': newOwnerId,
      'adminIds': FieldValue.arrayUnion([newOwnerId]),
    });
    batch.update(_members(groupId).doc(newOwnerId), {'role': 'owner'});
    batch.update(_members(groupId).doc(currentOwnerId), {'role': 'admin'});
    await batch.commit();
  }

  @override
  Future<void> joinViaInviteLink({
    required String groupId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  }) async {
    final now = Timestamp.now();
    
    // Fetch group to see if it belongs to a community
    final groupSnap = await _groups.doc(groupId).get();
    String? communityId;
    if (groupSnap.exists) {
      communityId = groupSnap.data()?['communityId'] as String?;
    }
    
    final batch = _db.batch();
    batch.update(_groups.doc(groupId), {
      'memberIds': FieldValue.arrayUnion([userId]),
      'activeMembers': FieldValue.arrayUnion([userId]),
      'unreadCount.$userId': 0,
    });
    batch.set(_members(groupId).doc(userId), {
      'name': userName,
      'avatarUrl': userAvatarUrl,
      'role': 'member',
      'joinedAt': now,
      'isOnline': true,
      'lastSeen': now,
      'muteUntil': null,
    });

    await batch.commit();

    // If group belongs to a community, attempt to add them to community members as well.
    // We execute this outside the main transaction in a try-catch block so that if the write fails
    // (e.g. security rules restrictions), the core group membership join still succeeds.
    if (communityId != null && communityId.isNotEmpty) {
      try {
        await _db.collection('communities').doc(communityId).collection('members').doc(userId).set({
          'role': 'member',
          'joinedAt': now,
          'userId': userId,
        });
      } catch (e) {
        debugPrint('[GroupRepository] Non-fatal: Failed to add user to community members: $e');
      }
    }
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    await removeMember(groupId: groupId, targetUserId: userId, actorId: userId);
  }

  @override
  Future<String> generateInviteLink(String groupId) async {
    final newLink = _uuid.v4();
    await _groups.doc(groupId).update({'inviteLink': newLink});
    return newLink;
  }

  // ── Messaging ──────────────────────────────────────────────────────────────

  @override
  Future<void> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String text,
    required List<String> memberIds,
    List<String> mediaUrls = const [],
    GroupMessageType messageType = GroupMessageType.text,
    int? audioDuration,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    List<String> mentionedUserIds = const [],
  }) async {
    if (text.trim().isEmpty && mediaUrls.isEmpty) return;

    final groupSnap = await _groups.doc(groupId).get();
    if (!groupSnap.exists) return;
    final groupData = groupSnap.data() ?? {};
    final isAnnouncementOnly =
        (groupData['isAnnouncementOnly'] as bool?) == true;

    final sid = senderId.trim();
    final memberIdsNorm = memberIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final mentionedNorm = mentionedUserIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final now = Timestamp.now();
    final msgRef = _msgs(groupId).doc();
    final batch = _db.batch();

    batch.set(msgRef, {
      'senderId': sid,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'text': text.trim(),
      'mediaUrls': mediaUrls,
      'messageType': _msgTypeToString(messageType),
      'audioDuration': audioDuration,
      'createdAt': now,
      'isEdited': false,
      'editedAt': null,
      'deletedForAll': false,
      'deletedForMe': [],
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSenderId': replyToSenderId,
      'replyToSenderName': replyToSenderName,
      'forwardedFromGroupId': null,
      'forwardedFromSenderId': null,
      'seenBy': {sid: now},
      'deliveredTo': {},
      'listenedBy': {},
      'reactions': {},
      'mentionedUserIds': mentionedNorm,
      'systemText': null,
    });

    // Increment unread for all non-senders (normalized IDs so sender is never counted)
    final otherIds = memberIdsNorm.where((id) => id != sid);
    final unreadIncrements = <String, dynamic>{};
    for (final id in otherIds) {
      unreadIncrements['unreadCount.$id'] = FieldValue.increment(1);
    }

    final preview = messageType == GroupMessageType.audio
        ? '🎤 Voice message'
        : (mediaUrls.isNotEmpty && text.trim().isEmpty
            ? (messageType == GroupMessageType.image ? '📷 Photo' : '📎 File')
            : text.trim());

    batch.update(_groups.doc(groupId), {
      'lastMessage': preview,
      'lastMessageSenderId': sid,
      'lastMessageAt': now,
      ...unreadIncrements,
    });

    // Write notification documents for FCM (Cloud Function picks them up)
    final targetIds = mentionedNorm.isNotEmpty
        ? mentionedNorm.where((id) => id != sid).toSet()
        : otherIds.toSet();

    if (!isAnnouncementOnly) {
      for (final id in targetIds) {
        if (!otherIds.contains(id)) continue;
        final isMention = mentionedNorm.contains(id);
        final notifRef = _db
            .collection('notifications')
            .doc('group_${groupId}_${msgRef.id}_$id');
        batch.set(notifRef, {
          'toUserId': id,
          'fromUserId': sid,
          'type': isMention ? 'group_mention' : 'group_message',
          'text': preview,
          'groupId': groupId,
          'messageId': msgRef.id,
          'createdAt': now,
          'read': false,
          'senderName': senderName,
          'senderAvatarUrl': senderAvatarUrl,
        });
      }
    }

    await batch.commit();
  }

  @override
  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
    required String editorId,
  }) async {
    await _msgs(groupId).doc(messageId).update({
      'text': newText.trim(),
      'isEdited': true,
      'editedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteMessageForMe({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    await _msgs(groupId).doc(messageId).update({
      'deletedForMe': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String groupId,
    required String messageId,
    required String senderId,
  }) async {
    final msgRef = _msgs(groupId).doc(messageId);
    final msgSnap = await msgRef.get();
    final msgData = msgSnap.data();
    final msgSenderId = (msgData?['senderId'] as String?) ?? senderId;
    final msgCreatedAt =
        (msgData?['createdAt'] as Timestamp?)?.toDate();

    await msgRef.update({
      'deletedForAll': true,
      'text': '',
      'mediaUrls': [],
    });

    if (msgCreatedAt == null) return;

    final groupRef = _groups.doc(groupId);
    final groupSnap = await groupRef.get();
    final groupData = groupSnap.data();
    final lastAt =
        (groupData?['lastMessageAt'] as Timestamp?)?.toDate();

    if (lastAt == null) return;
    if (lastAt.millisecondsSinceEpoch != msgCreatedAt.millisecondsSinceEpoch) {
      return;
    }

    await groupRef.update({
      'lastMessage': '🚫 This message was deleted',
      'lastMessageSenderId': msgSenderId,
    });
  }

  @override
  Future<void> reactToMessage({
    required String groupId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _msgs(groupId).doc(messageId).update({
      'reactions.$userId': emoji,
    });
  }

  @override
  Future<void> removeReaction({
    required String groupId,
    required String messageId,
    required String userId,
  }) async {
    await _msgs(groupId).doc(messageId).update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  @override
  Future<void> pinMessage({
    required String groupId,
    required String messageId,
    required String actorId,
  }) async {
    await _groups.doc(groupId).update({'pinnedMessageId': messageId});
  }

  @override
  Future<void> unpinMessage({
    required String groupId,
    required String actorId,
  }) async {
    await _groups.doc(groupId).update({'pinnedMessageId': null});
  }

  // ── Read Receipts ──────────────────────────────────────────────────────────

  @override
  Future<void> markSeen({
    required String groupId,
    required String userId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final now = Timestamp.now();
    var batch = _db.batch();
    var writes = 0;
    for (final id in messageIds) {
      batch.update(_msgs(groupId).doc(id), {'seenBy.$userId': now});
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();

    // Reset unread counter
    await _groups.doc(groupId).update({'unreadCount.$userId': 0});
  }

  @override
  Future<void> markListened({
    required String groupId,
    required String userId,
    required String messageId,
  }) async {
    final now = Timestamp.now();
    await _msgs(groupId).doc(messageId).update({'listenedBy.$userId': now});
  }

  // ── Typing ─────────────────────────────────────────────────────────────────

  @override
  Future<void> setTyping(String groupId, String userId, bool isTyping) async {
    final ref = _typing(groupId).doc(userId);
    if (isTyping) {
      await ref.set({'isTyping': true, 'updatedAt': Timestamp.now()});
    } else {
      await ref.delete();
    }
  }

  // ── Mute ───────────────────────────────────────────────────────────────────

  @override
  Future<void> muteGroup({
    required String groupId,
    required String userId,
    required DateTime muteUntil,
  }) async {
    await _members(groupId).doc(userId).update({
      'muteUntil': Timestamp.fromDate(muteUntil),
    });
  }

  @override
  Future<void> unmuteGroup({
    required String groupId,
    required String userId,
  }) async {
    await _members(groupId).doc(userId).update({'muteUntil': null});
  }

  // ── Search ──────────────────────────────────────────────────────────────────

  @override
  Future<List<GroupMessageEntity>> searchMessages({
    required String groupId,
    required String query,
  }) async {
    // Firestore doesn't support full-text search; we do client-side filtering
    // on the most recent 200 messages.
    final snap = await _msgs(groupId)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    final q = query.toLowerCase();
    return snap.docs
        .map((d) => GroupMessageModel.fromFirestore(d, groupId).toEntity())
        .where((m) => m.text.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<GroupMessageEntity>> getMediaMessages(String groupId) async {
    final snap = await _msgs(groupId)
        .where('messageType', whereIn: ['image', 'video', 'file'])
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snap.docs
        .map((d) => GroupMessageModel.fromFirestore(d, groupId).toEntity())
        .toList();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _deleteCollection(
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

  static String _msgTypeToString(GroupMessageType t) {
    switch (t) {
      case GroupMessageType.image:
        return 'image';
      case GroupMessageType.video:
        return 'video';
      case GroupMessageType.audio:
        return 'audio';
      case GroupMessageType.file:
        return 'file';
      case GroupMessageType.system:
        return 'system';
      case GroupMessageType.text:
        return 'text';
    }
  }
}
