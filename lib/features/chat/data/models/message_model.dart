import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
=======
import '../../domain/entities/message_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Firestore-aware data model that maps to/from [MessageEntity].
class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final List<String> mediaUrls;
  final String? audioUrl;
  final int? audioDuration;
  final ChatMessageType messageType;
  final DateTime createdAt;
  final MessageStatus status;

  final bool isEdited;
  final DateTime? editedAt;
  final bool deletedForAll;
  final List<String> deletedForMe;

  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;

  final Map<String, String> reactions;

  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    this.mediaUrls = const [],
    this.audioUrl,
    this.audioDuration,
    this.messageType = ChatMessageType.text,
    required this.createdAt,
    this.status = MessageStatus.sent,
    this.isEdited = false,
    this.editedAt,
    this.deletedForAll = false,
    this.deletedForMe = const [],
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToSenderName,
    this.reactions = const {},
  });

  // ── Firestore → Model ────────────────────────────────────────────────────

  factory MessageModel.fromFirestore(
    DocumentSnapshot doc,
    String conversationId,
  ) {
    final data = doc.data() as Map<String, dynamic>;

    // Fallback for legacy messages that only had `imageUrl`
    List<String> parsedMediaUrls = [];
    if (data['mediaUrls'] != null) {
      parsedMediaUrls = List<String>.from(data['mediaUrls'] as List);
    } else if (data['imageUrl'] != null) {
      parsedMediaUrls = [data['imageUrl'] as String];
    }

    return MessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? '',
      senderAvatarUrl: (data['senderAvatarUrl'] as String?)?.trim(),
      text: data['text'] as String? ?? '',
      mediaUrls: parsedMediaUrls,
      audioUrl: (data['audioUrl'] as String?)?.trim(),
      audioDuration: data['audioDuration'] as int?,
      messageType: _messageTypeFromFirestore(data['messageType'] as String?),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _statusFromFirestore(data),
      isEdited: data['isEdited'] as bool? ?? false,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
      deletedForAll: data['deletedForAll'] as bool? ?? false,
      deletedForMe: List<String>.from(data['deletedForMe'] as List? ?? []),
      replyToMessageId: data['replyToMessageId'] as String?,
      replyToText: data['replyToText'] as String?,
      replyToSenderId: data['replyToSenderId'] as String?,
      replyToSenderName: data['replyToSenderName'] as String?,
      reactions: Map<String, String>.from(data['reactions'] as Map? ?? {}),
    );
  }

  /// Resolves status, falling back to legacy `isRead` bool if needed.
  static MessageStatus _statusFromFirestore(Map<String, dynamic> data) {
    final raw = data['status'] as String?;
    if (raw != null) {
      switch (raw) {
        case 'sending':
          return MessageStatus.sending;
        case 'delivered':
          return MessageStatus.delivered;
        case 'seen':
          return MessageStatus.seen;
        default:
          return MessageStatus.sent;
      }
    }
    // Legacy fallback
    final isRead = data['isRead'] as bool? ?? false;
    return isRead ? MessageStatus.seen : MessageStatus.sent;
  }

  static ChatMessageType _messageTypeFromFirestore(String? raw) {
    if (raw == null) return ChatMessageType.text;
    switch (raw) {
      case 'image': return ChatMessageType.image;
      case 'audio': return ChatMessageType.audio;
      case 'video': return ChatMessageType.video;
      case 'file': return ChatMessageType.file;
      default: return ChatMessageType.text;
    }
  }

  // ── Model → Firestore ────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'text': text,
        'mediaUrls': mediaUrls,
        'audioUrl': audioUrl,
        'audioDuration': audioDuration,
        'messageType': messageType.name,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': _statusToString(status),
        'isRead': status == MessageStatus.seen,
        'isEdited': isEdited,
        if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
        'deletedForAll': deletedForAll,
        'deletedForMe': deletedForMe,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToSenderId': replyToSenderId,
        'replyToSenderName': replyToSenderName,
        'reactions': reactions,
      };

  static String _statusToString(MessageStatus s) {
    switch (s) {
      case MessageStatus.sending:
        return 'sending';
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.seen:
        return 'seen';
    }
  }

  // ── Model → Entity ───────────────────────────────────────────────────────

  MessageEntity toEntity() => MessageEntity(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        mediaUrls: mediaUrls,
        audioUrl: audioUrl,
        audioDuration: audioDuration,
        messageType: messageType,
        createdAt: createdAt,
        status: status,
        isEdited: isEdited,
        editedAt: editedAt,
        deletedForAll: deletedForAll,
        deletedForMe: deletedForMe,
        replyToMessageId: replyToMessageId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        reactions: reactions,
      );
}
