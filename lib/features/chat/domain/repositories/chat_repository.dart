import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';

/// Abstract repository interface — the Domain layer contract.
/// The Data layer provides the concrete implementation.
abstract class ChatRepository {
  // ── Conversations ─────────────────────────────────────────────────────────

  /// Real-time stream of all conversations for [userId], ordered by
  /// [lastMessageAt] descending.
  Stream<List<ConversationEntity>> watchConversations(String userId);

  /// Real-time stream of total unread message count across all conversations.
  Stream<int> watchTotalUnread(String userId);

  /// Fetches or creates a 1-to-1 conversation between two users.
  Future<ConversationEntity> getOrCreateConversation({
    required String myId,
    required String myName,
    required String? myAvatar,
    required String otherId,
    required String otherName,
    required String? otherAvatar,
  });

  /// Deletes a 1-to-1 conversation.
  Future<void> deleteConversation(String conversationId);

  /// Deletes multiple conversations in a batch operation.
  Future<void> deleteConversationsBatch(List<String> conversationIds, String userId);

  /// Mutes or unmutes a conversation for a specific user.
  Future<void> muteConversation(String conversationId, String userId, DateTime? muteUntil);

  /// Archives or unarchives multiple conversations in a batch operation.
  Future<void> archiveConversationsBatch(List<String> conversationIds, String userId, bool archive);

  /// Pins or unpins multiple conversations in a batch operation.
  Future<void> pinConversationsBatch(List<String> conversationIds, String userId, bool pin);

  /// Real-time stream of archived conversations for [userId].
  Stream<List<ConversationEntity>> watchArchivedConversations(String userId);

  // ── Messages ──────────────────────────────────────────────────────────────

  /// Real-time stream of the **first page** of messages for [conversationId],
  /// ordered by [createdAt] ascending, limited to [pageSize].
  Stream<List<MessageEntity>> watchMessages(
    String conversationId, {
    int pageSize = 30,
  });

  /// Loads the next page of older messages before [beforeMessageId].
  /// Returns an empty list when there are no more messages.
  Future<List<MessageEntity>> loadMoreMessages(
    String conversationId, {
    required String beforeMessageId,
    int pageSize = 30,
  });

  /// Sends a new message to [conversationId].
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
  });

  /// Marks all messages from others as [MessageStatus.delivered].
  /// Call this when the user opens the conversation screen.
  Future<void> markDelivered(String conversationId, String myUserId);

  /// Marks all messages from others as [MessageStatus.seen] and resets
  /// the unread count to 0. Call when the chat screen is focused.
  Future<void> markSeen(String conversationId, String myUserId);

  /// Deletes a single message (hard delete) - legacy.
  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  });

  /// Deletes a message for everyone (if within cutoff).
  Future<void> deleteMessageForEveryone({
    required String conversationId,
    required String messageId,
  });

  /// Deletes a message only for the current user.
  Future<void> deleteMessageForMe({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  /// Edits an existing message's text.
  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String newText,
  });

  /// Reacts to a message with an emoji.
  Future<void> reactToMessage({
    required String conversationId,
    required String messageId,
    required String userId,
    required String emoji,
  });

  /// Removes a reaction from a message.
  Future<void> removeReaction({
    required String conversationId,
    required String messageId,
    required String userId,
  });

  // ── Typing Indicator ──────────────────────────────────────────────────────

  /// Writes or clears the typing status for [userId] in [conversationId].
  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  );

  /// Real-time stream of whether [otherUserId] is currently typing.
  Stream<bool> watchTyping(String conversationId, String otherUserId);
}
