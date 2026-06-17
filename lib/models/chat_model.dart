import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final String? imageUrl;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    required this.createdAt,
    this.isRead = false,
    this.imageUrl,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderAvatarUrl: (data['senderAvatarUrl'] as String?)?.trim(),
      text: data['text'] as String? ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      imageUrl: (data['imageUrl'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'text': text,
        'createdAt': Timestamp.fromDate(createdAt),
        'isRead': isRead,
        'imageUrl': imageUrl,
      };
}

class ConversationModel {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final Map<String, String?> participantAvatars;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;

  ConversationModel({
    required this.id,
    required this.participantIds,
    required this.participantNames,
    required this.participantAvatars,
    required this.lastMessage,
    required this.lastMessageSenderId,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ConversationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final pNames = (data['participantNames'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v?.toString() ?? '')) ??
        {};
    final pAvatars = (data['participantAvatars'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v?.toString())) ??
        {};
    final unread = (data['unreadCount'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as int?) ?? 0)) ??
        {};

    return ConversationModel(
      id: doc.id,
      participantIds:
          List<String>.from(data['participantIds'] as List? ?? []),
      participantNames: pNames,
      participantAvatars: pAvatars,
      lastMessage: data['lastMessage'] as String? ?? '',
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: unread,
    );
  }

  /// Get the other participant's ID (in a 1-to-1 conversation)
  String otherUserId(String myId) =>
      participantIds.firstWhere((id) => id != myId, orElse: () => '');

  String otherUserName(String myId) =>
      participantNames[otherUserId(myId)] ?? '';

  String? otherUserAvatar(String myId) =>
      participantAvatars[otherUserId(myId)];

  int myUnread(String myId) => unreadCount[myId] ?? 0;
}
