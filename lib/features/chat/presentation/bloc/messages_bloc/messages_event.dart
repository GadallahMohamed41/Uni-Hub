import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
=======
import '../../../domain/entities/message_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class MessagesEvent extends Equatable {
  const MessagesEvent();
  @override
  List<Object?> get props => [];
}

/// Subscribe to real-time messages for [conversationId].
class MessagesStarted extends MessagesEvent {
  final String conversationId;
  final String myUserId;
  const MessagesStarted({
    required this.conversationId,
    required this.myUserId,
  });
  @override
  List<Object?> get props => [conversationId, myUserId];
}

/// Load older messages (pagination).
class MessagesLoadMore extends MessagesEvent {
  const MessagesLoadMore();
}

/// Send a new message (text or audio).
class MessageSent extends MessagesEvent {
  final String? messageId;
  final String text;
  final List<String> participantIds;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String? audioUrl;
  final int? audioDuration;
  final ChatMessageType messageType;
  final List<String> mediaUrls;
  final MessageEntity? replyingTo;

  const MessageSent({
    this.messageId,
    required this.text,
    required this.participantIds,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    this.audioUrl,
    this.audioDuration,
    this.messageType = ChatMessageType.text,
    this.mediaUrls = const [],
    this.replyingTo,
  });
  @override
  List<Object?> get props => [messageId, text, senderId, audioUrl, messageType];
}

class LocalMessageUpserted extends MessagesEvent {
  final MessageEntity message;
  const LocalMessageUpserted(this.message);
  @override
  List<Object?> get props => [message];
}

class LocalMessageRemoved extends MessagesEvent {
  final String messageId;
  const LocalMessageRemoved(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

/// Mark all messages as seen (conversation focused).
class MessagesSeen extends MessagesEvent {
  const MessagesSeen();
}

/// Set or clear typing indicator.
class TypingStatusChanged extends MessagesEvent {
  final bool isTyping;
  const TypingStatusChanged(this.isTyping);
  @override
  List<Object?> get props => [isTyping];
}

class MessageDeleted extends MessagesEvent {
  final String messageId;
  const MessageDeleted(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class MessageDeletedForMe extends MessagesEvent {
  final String messageId;
  const MessageDeletedForMe(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class MessageDeletedForEveryone extends MessagesEvent {
  final String messageId;
  const MessageDeletedForEveryone(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class MessageEdited extends MessagesEvent {
  final String messageId;
  final String newText;
  const MessageEdited({required this.messageId, required this.newText});
  @override
  List<Object?> get props => [messageId, newText];
}

class MessageReacted extends MessagesEvent {
  final String messageId;
  final String emoji;
  const MessageReacted({required this.messageId, required this.emoji});
  @override
  List<Object?> get props => [messageId, emoji];
}

class MessageRemovedReaction extends MessagesEvent {
  final String messageId;
  const MessageRemovedReaction(this.messageId);
  @override
  List<Object?> get props => [messageId];
}

class MessageReplySet extends MessagesEvent {
  final MessageEntity? replyingTo;
  const MessageReplySet(this.replyingTo);
  @override
  List<Object?> get props => [replyingTo];
}
