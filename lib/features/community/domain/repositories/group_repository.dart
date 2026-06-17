import '../entities/group_entity.dart';
import '../entities/group_member_entity.dart';
import '../entities/group_message_entity.dart';

/// Abstract repository contract for all Group operations.
/// Implementations live in the data layer.
abstract class GroupRepository {
  // ── Group CRUD ─────────────────────────────────────────────────────────────

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
  });

  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    String? imageUrl,
    WhoCanSend? whoCanSend,
    bool? isPublic,
  });

  Future<void> deleteGroup(String groupId);

  Future<GroupEntity?> getGroup(String groupId);

  /// Find a group by its invite link token.
  Future<GroupEntity?> getGroupByInviteLink(String inviteLink);

  // ── Real-time streams ──────────────────────────────────────────────────────

  /// Stream of groups the user belongs to, ordered by lastMessageAt.
  Stream<List<GroupEntity>> watchUserGroups(String userId);

  /// Stream of a single group's details.
  Stream<GroupEntity?> watchGroup(String groupId);

  /// Stream of messages in a group (newest first, paginated).
  Stream<List<GroupMessageEntity>> watchMessages(
    String groupId, {
    int pageSize = 40,
  });

  /// Load older messages (cursor-based pagination).
  Future<List<GroupMessageEntity>> loadMoreMessages(
    String groupId, {
    required String beforeMessageId,
    int pageSize = 30,
  });

  /// Stream of member list for a group.
  Stream<List<GroupMemberEntity>> watchMembers(String groupId);

  /// Stream of who is currently typing (list of userIds).
  Stream<List<String>> watchTyping(String groupId);

  // ── Member Management ──────────────────────────────────────────────────────

  Future<void> addMembers({
    required String groupId,
    required List<String> newMemberIds,
    required List<String> newMemberNames,
    required List<String?> newMemberAvatarUrls,
  });

  Future<void> removeMember({
    required String groupId,
    required String targetUserId,
    required String actorId,
  });

  Future<void> promoteToAdmin({
    required String groupId,
    required String targetUserId,
    required String actorId,
  });

  Future<void> demoteFromAdmin({
    required String groupId,
    required String targetUserId,
    required String actorId,
  });

  Future<void> transferOwnership({
    required String groupId,
    required String newOwnerId,
    required String currentOwnerId,
  });

  Future<void> joinViaInviteLink({
    required String groupId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  });

  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  });

  Future<String> generateInviteLink(String groupId);

  // ── Messaging ──────────────────────────────────────────────────────────────

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
  });

  Future<void> editMessage({
    required String groupId,
    required String messageId,
    required String newText,
    required String editorId,
  });

  Future<void> deleteMessageForMe({
    required String groupId,
    required String messageId,
    required String userId,
  });

  Future<void> deleteMessageForEveryone({
    required String groupId,
    required String messageId,
    required String senderId,
  });

  Future<void> reactToMessage({
    required String groupId,
    required String messageId,
    required String userId,
    required String emoji,
  });

  Future<void> removeReaction({
    required String groupId,
    required String messageId,
    required String userId,
  });

  Future<void> pinMessage({
    required String groupId,
    required String messageId,
    required String actorId,
  });

  Future<void> unpinMessage({
    required String groupId,
    required String actorId,
  });

  // ── Read Receipts ──────────────────────────────────────────────────────────

  /// Mark all visible messages as seen by [userId].
  Future<void> markSeen({
    required String groupId,
    required String userId,
    required List<String> messageIds,
  });

  Future<void> markListened({
    required String groupId,
    required String userId,
    required String messageId,
  });

  // ── Typing ─────────────────────────────────────────────────────────────────

  Future<void> setTyping(String groupId, String userId, bool isTyping);

  // ── Mute ───────────────────────────────────────────────────────────────────

  Future<void> muteGroup({
    required String groupId,
    required String userId,
    required DateTime muteUntil,
  });

  Future<void> unmuteGroup({
    required String groupId,
    required String userId,
  });

  // ── Search ──────────────────────────────────────────────────────────────────

  Future<List<GroupMessageEntity>> searchMessages({
    required String groupId,
    required String query,
  });

  Future<List<GroupMessageEntity>> getMediaMessages(String groupId);
}
