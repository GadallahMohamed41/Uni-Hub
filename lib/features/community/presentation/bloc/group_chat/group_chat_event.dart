import 'package:equatable/equatable.dart';
import '../../../domain/entities/group_entity.dart';
import '../../../domain/entities/group_member_entity.dart';
import '../../../domain/entities/group_message_entity.dart';

abstract class GroupChatEvent extends Equatable {
  const GroupChatEvent();
  @override
  List<Object?> get props => [];
}

// ── Lifecycle ────────────────────────────────────────────────────────────────

class GroupChatStarted extends GroupChatEvent {
  final String groupId;
  final String currentUserId;
  const GroupChatStarted({required this.groupId, required this.currentUserId});
  @override
  List<Object?> get props => [groupId, currentUserId];
}

class GroupChatMessagesUpdated extends GroupChatEvent {
  final List<GroupMessageEntity> messages;
  const GroupChatMessagesUpdated(this.messages);
  @override
  List<Object?> get props => [messages];
}

class GroupChatGroupUpdated extends GroupChatEvent {
  final GroupEntity group;
  const GroupChatGroupUpdated(this.group);
  @override
  List<Object?> get props => [group];
}

class GroupChatMembersUpdated extends GroupChatEvent {
  final List<GroupMemberEntity> members;
  const GroupChatMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

class GroupChatTypingUpdated extends GroupChatEvent {
  final List<String> typingUserIds;
  const GroupChatTypingUpdated(this.typingUserIds);
  @override
  List<Object?> get props => [typingUserIds];
}

// ── Messaging ────────────────────────────────────────────────────────────────

class GroupChatSendMessage extends GroupChatEvent {
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String text;
  final List<String> mediaUrls;
  final GroupMessageType messageType;
  final int? audioDuration;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final List<String> mentionedUserIds;

  const GroupChatSendMessage({
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    this.mediaUrls = const [],
    this.messageType = GroupMessageType.text,
    this.audioDuration,
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToSenderName,
    this.mentionedUserIds = const [],
  });

  @override
  List<Object?> get props =>
      [senderId, text, mediaUrls, replyToMessageId, mentionedUserIds];
}

class GroupChatEditMessage extends GroupChatEvent {
  final String messageId;
  final String newText;
  final String editorId;
  const GroupChatEditMessage({
    required this.messageId,
    required this.newText,
    required this.editorId,
  });
  @override
  List<Object?> get props => [messageId, newText];
}

class GroupChatDeleteMessageForMe extends GroupChatEvent {
  final String messageId;
  final String userId;
  const GroupChatDeleteMessageForMe(
      {required this.messageId, required this.userId});
  @override
  List<Object?> get props => [messageId, userId];
}

class GroupChatDeleteMessageForEveryone extends GroupChatEvent {
  final String messageId;
  final String senderId;
  const GroupChatDeleteMessageForEveryone(
      {required this.messageId, required this.senderId});
  @override
  List<Object?> get props => [messageId, senderId];
}

class GroupChatReactToMessage extends GroupChatEvent {
  final String messageId;
  final String userId;
  final String emoji;
  const GroupChatReactToMessage({
    required this.messageId,
    required this.userId,
    required this.emoji,
  });
  @override
  List<Object?> get props => [messageId, userId, emoji];
}

class GroupChatRemoveReaction extends GroupChatEvent {
  final String messageId;
  final String userId;
  const GroupChatRemoveReaction(
      {required this.messageId, required this.userId});
  @override
  List<Object?> get props => [messageId, userId];
}

// ── Pagination ───────────────────────────────────────────────────────────────

class GroupChatLoadMore extends GroupChatEvent {
  const GroupChatLoadMore();
}

// ── Typing ───────────────────────────────────────────────────────────────────

class GroupChatTypingChanged extends GroupChatEvent {
  final String userId;
  final bool isTyping;
  const GroupChatTypingChanged({required this.userId, required this.isTyping});
  @override
  List<Object?> get props => [userId, isTyping];
}

// ── Reply state ──────────────────────────────────────────────────────────────

class GroupChatSetReply extends GroupChatEvent {
  final GroupMessageEntity? message;
  const GroupChatSetReply(this.message);
  @override
  List<Object?> get props => [message?.id];
}

// ── Admin actions ────────────────────────────────────────────────────────────

class GroupChatPinMessage extends GroupChatEvent {
  final String messageId;
  final String actorId;
  const GroupChatPinMessage({required this.messageId, required this.actorId});
  @override
  List<Object?> get props => [messageId];
}

class GroupChatUnpinMessage extends GroupChatEvent {
  final String actorId;
  const GroupChatUnpinMessage({required this.actorId});
  @override
  List<Object?> get props => [actorId];
}

// ── Mark seen ────────────────────────────────────────────────────────────────

class GroupChatMarkSeen extends GroupChatEvent {
  final String userId;
  final List<String> messageIds;
  const GroupChatMarkSeen({required this.userId, required this.messageIds});
  @override
  List<Object?> get props => [userId, messageIds];
}

class GroupChatMarkListened extends GroupChatEvent {
  final String userId;
  final String messageId;
  const GroupChatMarkListened({required this.userId, required this.messageId});
  @override
  List<Object?> get props => [userId, messageId];
}

// ── Error ────────────────────────────────────────────────────────────────────

class GroupChatErrorCleared extends GroupChatEvent {
  const GroupChatErrorCleared();
}

