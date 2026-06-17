import 'package:equatable/equatable.dart';

/// Represents the delivery lifecycle of a single message.
enum MessageStatus {
  /// Being written to Firestore (optimistic local state).
  sending,

  /// Written to Firestore successfully; recipient not yet online.
  sent,

  /// Recipient's device has opened the conversation (screen visible).
  delivered,

  /// Recipient has read the message (chat screen focused).
  seen,
}

enum ChatMessageType { text, image, audio, video, file }

/// Core domain entity for a single chat message.
/// Pure Dart — no Firebase imports here.
class MessageEntity extends Equatable {
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

  // Edit
  final bool isEdited;
  final DateTime? editedAt;

  // Delete
  final bool deletedForAll;
  final List<String> deletedForMe;

  // Reply
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;

  // Reactions
  final Map<String, String> reactions;

  const MessageEntity({
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

  /// Convenience — backward-compat with old `isRead` bool.
  bool get isRead => status == MessageStatus.seen;

  bool get isSeen => status == MessageStatus.seen;
  bool get isDelivered =>
      status == MessageStatus.delivered || status == MessageStatus.seen;

  bool isDeletedForUser(String uid) =>
      deletedForAll || deletedForMe.contains(uid);

  MessageEntity copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    List<String>? mediaUrls,
    String? audioUrl,
    int? audioDuration,
    ChatMessageType? messageType,
    DateTime? createdAt,
    MessageStatus? status,
    bool? isEdited,
    DateTime? editedAt,
    bool? deletedForAll,
    List<String>? deletedForMe,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    Map<String, String>? reactions,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      audioUrl: audioUrl ?? this.audioUrl,
      audioDuration: audioDuration ?? this.audioDuration,
      messageType: messageType ?? this.messageType,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      deletedForAll: deletedForAll ?? this.deletedForAll,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      reactions: reactions ?? this.reactions,
    );
  }

  @override
  List<Object?> get props => [
        id,
        conversationId,
        senderId,
        text,
        mediaUrls,
        audioUrl,
        audioDuration,
        messageType,
        createdAt,
        status,
        isEdited,
        deletedForAll,
        deletedForMe,
        reactions,
      ];
}
