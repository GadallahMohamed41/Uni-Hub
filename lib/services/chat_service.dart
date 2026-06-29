import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/models/chat_model.dart';
=======
import '../models/chat_model.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Generate deterministic conversation ID from two user IDs ─────────────
  String _conversationId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // ── Get or create a 1-to-1 conversation ──────────────────────────────────
  Future<ConversationModel> getOrCreateConversation({
    required String myId,
    required String myName,
    required String? myAvatar,
    required String otherId,
    required String otherName,
    required String? otherAvatar,
  }) async {
    final convId = _conversationId(myId, otherId);
    final ref = _db.collection('conversations').doc(convId);
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
      return ConversationModel.fromFirestore(await ref.get());
    }

    // Update participant info in case names/avatars changed
    await ref.update({
      'participantNames.$myId': myName,
      'participantNames.$otherId': otherName,
      if (myAvatar != null) 'participantAvatars.$myId': myAvatar,
      if (otherAvatar != null) 'participantAvatars.$otherId': otherAvatar,
    });

    return ConversationModel.fromFirestore(snap);
  }

  // ── Stream all conversations for a user ───────────────────────────────────
  Stream<List<ConversationModel>> getConversationsStream(String userId) {
    return _db
        .collection('conversations')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ConversationModel.fromFirestore(d)).toList());
  }

  // ── Stream unread total count for badge ───────────────────────────────────
  Stream<int> getTotalUnreadStream(String userId) {
    return getConversationsStream(userId).map((conversations) {
      return conversations.fold<int>(0, (total, c) => total + c.myUnread(userId));
    });
  }

  // ── Stream messages in a conversation ─────────────────────────────────────
  Stream<List<MessageModel>> getMessagesStream(String conversationId) {
    return _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => MessageModel.fromFirestore(d)).toList());
  }

  // ── Send a message ────────────────────────────────────────────────────────
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatar,
    required String text,
    required List<String> participantIds,
  }) async {
    if (text.trim().isEmpty) return;

    final convRef = _db.collection('conversations').doc(conversationId);
    final msgRef = convRef.collection('messages').doc();

    final now = Timestamp.now();

    final batch = _db.batch();

    // Add message
    batch.set(msgRef, {
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatar,
      'text': text.trim(),
      'createdAt': now,
      'isRead': false,
    });

    // Update conversation metadata
    final otherIds = participantIds.where((id) => id != senderId).toList();
    final unreadIncrements = <String, dynamic>{};
    for (final id in otherIds) {
      unreadIncrements['unreadCount.$id'] = FieldValue.increment(1);

      // Add a notification for each recipient
      final notifRef = _db.collection('notifications').doc('chat_${conversationId}_${msgRef.id}_$id');
      batch.set(notifRef, {
        'toUserId': id,
        'fromUserId': senderId,
        'type': 'chat_message',
        'text': text.trim(),
        'conversationId': conversationId,
        'createdAt': now,
        'read': false,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatar,
      });
    }

    batch.update(convRef, {
      'lastMessage': text.trim(),
      'lastMessageSenderId': senderId,
      'lastMessageAt': now,
      ...unreadIncrements,
    });

    await batch.commit();
  }

  // ── Mark conversation as read for current user ────────────────────────────
  Future<void> markAsRead(String conversationId, String userId) async {
    // Reset unread count
    await _db.collection('conversations').doc(conversationId).update({
      'unreadCount.$userId': 0,
    });

    // Mark all unread messages as read
    final snap = await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    if (snap.docs.isEmpty) return;

    var batch = _db.batch();
    var writes = 0;
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
      writes++;
      if (writes >= 450) {
        await batch.commit();
        batch = _db.batch();
        writes = 0;
      }
    }
    if (writes > 0) await batch.commit();
  }

  // ── Delete a message (soft/hard) ──────────────────────────────────────────
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _db
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }
}
