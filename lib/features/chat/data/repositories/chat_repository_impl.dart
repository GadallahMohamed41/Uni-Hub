import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Deterministic conversation ID from two user IDs.
  static String conversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  CollectionReference<Map<String, dynamic>> get _convs =>
      _db.collection('conversations');

  CollectionReference<Map<String, dynamic>> _msgs(String convId) =>
      _convs.doc(convId).collection('messages');

  CollectionReference<Map<String, dynamic>> _typing(String convId) =>
      _convs.doc(convId).collection('typing');

  // ── Conversations ─────────────────────────────────────────────────────────

  @override
  Stream<List<ConversationEntity>> watchConversations(String userId) {
    return _convs
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConversationModel.fromFirestore(d).toEntity())
            .where((e) => !e.isArchived(userId))
            .toList());
  }

  @override
  Stream<int> watchTotalUnread(String userId) {
    return watchConversations(userId).map((convs) =>
        convs.fold<int>(0, (total, c) => total + c.myUnread(userId)));
  }

  @override
  Future<ConversationEntity> getOrCreateConversation({
    required String myId,
    required String myName,
    required String? myAvatar,
    required String otherId,
    required String otherName,
    required String? otherAvatar,
  }) async {
    final convId = conversationId(myId, otherId);
    final ref = _convs.doc(convId);
    final snap = await ref.get();

    if (!snap.exists) {
      final data = {
        'participantIds': [myId, otherId],
        'participantNames': {myId: myName, otherId: otherName},
        'participantAvatars': {
          myId: myAvatar,
          otherId: otherAvatar,
        },
        'lastMessage': '',
        'lastMessageSenderId': '',
        'lastMessageAt': Timestamp.now(),
        'unreadCount': {myId: 0, otherId: 0},
      };
      await ref.set(data);
      return ConversationModel.fromFirestore(await ref.get()).toEntity();
    }

    // Update participant display info in case name/avatar changed
    await ref.update({
      'participantNames.$myId': myName,
      'participantNames.$otherId': otherName,
      if (myAvatar != null) 'participantAvatars.$myId': myAvatar,
      if (otherAvatar != null) 'participantAvatars.$otherId': otherAvatar,
    });

    return ConversationModel.fromFirestore(snap).toEntity();
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _convs.doc(conversationId).delete();
  }

  @override
  Future<void> deleteConversationsBatch(List<String> conversationIds, String userId) async {
    final batch = _db.batch();
    for (final id in conversationIds) {
      batch.update(_convs.doc(id), {
        'participantIds': FieldValue.arrayRemove([userId]),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> muteConversation(String conversationId, String userId, DateTime? muteUntil) async {
    if (muteUntil == null) {
      await _convs.doc(conversationId).update({
        'muteUntil.$userId': FieldValue.delete(),
      });
    } else {
      await _convs.doc(conversationId).update({
        'muteUntil.$userId': Timestamp.fromDate(muteUntil),
      });
    }
  }

  @override
  Future<void> archiveConversationsBatch(List<String> conversationIds, String userId, bool archive) async {
    final batch = _db.batch();
    for (final id in conversationIds) {
      batch.update(_convs.doc(id), {
        'archivedBy.$userId': archive ? true : FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> pinConversationsBatch(List<String> conversationIds, String userId, bool pin) async {
    final batch = _db.batch();
    for (final id in conversationIds) {
      batch.update(_convs.doc(id), {
        'pinnedBy.$userId': pin ? FieldValue.serverTimestamp() : FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  @override
  Stream<List<ConversationEntity>> watchArchivedConversations(String userId) {
    return _convs
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ConversationModel.fromFirestore(d).toEntity())
            .where((e) => e.isArchived(userId))
            .toList());
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  @override
  Stream<List<MessageEntity>> watchMessages(
    String conversationId, {
    int pageSize = 30,
  }) {
    return _msgs(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .snapshots()
        .map((snap) {
      final messages = snap.docs
          .map((d) => MessageModel.fromFirestore(d, conversationId).toEntity())
          .toList();
      // Reverse so oldest is at top
      return messages.reversed.toList();
    });
  }

  @override
  Future<List<MessageEntity>> loadMoreMessages(
    String conversationId, {
    required String beforeMessageId,
    int pageSize = 30,
  }) async {
    // Get the cursor document
    final cursorDoc =
        await _msgs(conversationId).doc(beforeMessageId).get();
    if (!cursorDoc.exists) return [];

    final snap = await _msgs(conversationId)
        .orderBy('createdAt', descending: true)
        .startAfterDocument(cursorDoc)
        .limit(pageSize)
        .get();

    final messages = snap.docs
        .map((d) => MessageModel.fromFirestore(d, conversationId).toEntity())
        .toList();
    // Reverse so oldest is at top
    return messages.reversed.toList();
  }

  @override
  Future<void> sendMessage({
    String? messageId,
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatar,
    required String text,
    required List<String> participantIds,
    List<String> mediaUrls = const [],
    String? audioUrl,
    int? audioDuration,
    ChatMessageType messageType = ChatMessageType.text,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
  }) async {
    if (text.trim().isEmpty && mediaUrls.isEmpty && audioUrl == null) return;

    final convRef = _convs.doc(conversationId);
    final msgRef = messageId == null || messageId.trim().isEmpty
        ? _msgs(conversationId).doc()
        : _msgs(conversationId).doc(messageId.trim());
    final now = Timestamp.now();
    final batch = _db.batch();

    // Write message with status: 'sent'
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatar,
      'text': text.trim(),
      'mediaUrls': mediaUrls,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'messageType': messageType.name,
      'createdAt': now,
      'status': 'sent',
      'isRead': false, // backward compat
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
      'replyToSenderId': replyToSenderId,
      'replyToSenderName': replyToSenderName,
    });

    final preview = messageType == ChatMessageType.audio
        ? '🎤 Voice message'
        : (mediaUrls.isNotEmpty ? '📷 Photo' : text.trim());

    // Increment unread count for all non-senders
    final otherIds = participantIds.where((id) => id != senderId).toList();
    final unreadIncrements = <String, dynamic>{};
    for (final id in otherIds) {
      unreadIncrements['unreadCount.$id'] = FieldValue.increment(1);

      // Write a notification document — Cloud Function will fire FCM
      final notifRef = _db.collection('notifications').doc(
          'chat_${conversationId}_${msgRef.id}_$id');
      batch.set(notifRef, {
        'toUserId': id,
        'fromUserId': senderId,
        'type': 'chat_message',
        'text': preview,
        'conversationId': conversationId,
        'createdAt': now,
        'read': false,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatar,
      });
    }

    batch.update(convRef, {
      'lastMessage': preview,
      'lastMessageSenderId': senderId,
      'lastMessageAt': now,
      ...unreadIncrements,
    });

    await batch.commit();
  }

  @override
  Future<void> markDelivered(String conversationId, String myUserId) async {
    // Mark messages sent by the OTHER user to 'delivered'
    final snap = await _msgs(conversationId)
        .where('senderId', isNotEqualTo: myUserId)
        .where('status', isEqualTo: 'sent')
        .get();

    if (snap.docs.isEmpty) return;

    var batch = _db.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'status': 'delivered'});
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();
  }

  @override
  Future<void> markSeen(String conversationId, String myUserId) async {
    // Reset unread counter
    await _convs.doc(conversationId).update({
      'unreadCount.$myUserId': 0,
    });

    // Mark messages sent by others as 'seen'
    final snap = await _msgs(conversationId)
        .where('senderId', isNotEqualTo: myUserId)
        .where('status', whereIn: ['sent', 'delivered'])
        .get();

    if (snap.docs.isEmpty) return;

    var batch = _db.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'status': 'seen',
        'isRead': true, // backward compat
      });
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();
  }

  @override
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _msgs(conversationId).doc(messageId).delete();
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  }) async {
    final msgRef = _msgs(conversationId).doc(messageId);
    final msgSnap = await msgRef.get();
    final msgData = msgSnap.data();
    final msgSenderId = (msgData?['senderId'] as String?) ?? '';
    final msgCreatedAt =
        (msgData?['createdAt'] as Timestamp?)?.toDate();

    await msgRef.update({
      'deletedForAll': true,
      'text': '',
      'mediaUrls': [],
      'audioUrl': null,
    });

    if (msgCreatedAt == null) return;

    final convRef = _convs.doc(conversationId);
    final convSnap = await convRef.get();
    final convData = convSnap.data();
    final lastAt =
        (convData?['lastMessageAt'] as Timestamp?)?.toDate();

    if (lastAt == null) return;
    if (lastAt.millisecondsSinceEpoch != msgCreatedAt.millisecondsSinceEpoch) {
      return;
    }

    await convRef.update({
      'lastMessage': '🚫 This message was deleted',
      'lastMessageSenderId': msgSenderId,
    });
  }

  @override
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    await _msgs(conversationId).doc(messageId).update({
      'deletedForMe': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  }) async {
    await _msgs(conversationId).doc(messageId).update({
      'text': newText.trim(),
      'isEdited': true,
      'editedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> reactToMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await _msgs(conversationId).doc(messageId).update({
      'reactions.$userId': emoji,
    });
  }

  @override
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String userId,
  }) async {
    await _msgs(conversationId).doc(messageId).update({
      'reactions.$userId': FieldValue.delete(),
    });
  }

  // ── Typing Indicator ──────────────────────────────────────────────────────

  @override
  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    final ref = _typing(conversationId).doc(userId);
    if (isTyping) {
      await ref.set({
        'isTyping': true,
        'updatedAt': Timestamp.now(),
      });
    } else {
      await ref.delete();
    }
  }

  @override
  Stream<bool> watchTyping(String conversationId, String otherUserId) {
    return _typing(conversationId)
        .doc(otherUserId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return false;
      final data = snap.data();
      if (data == null) return false;

      final isTyping = data['isTyping'] as bool? ?? false;
      if (!isTyping) return false;

      // Auto-expire: if updatedAt is > 6 seconds ago, treat as not typing
      final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
      if (updatedAt == null) return false;
      return DateTime.now().difference(updatedAt).inSeconds < 6;
    });
  }
}
