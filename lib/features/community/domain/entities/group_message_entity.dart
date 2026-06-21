import 'package:equatable/equatable.dart';

/// Types of group messages.
enum GroupMessageType { text, image, video, audio, file, system }

/// Delete scope — for the delete-for-everyone 10-min window.
enum DeleteScope { forMe, forEveryone }

/// Domain entity for a single group message.
/// Pure Dart — no Firebase imports.
class GroupMessageEntity extends Equatable {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;

  final String text;
  final List<String> mediaUrls;
  final GroupMessageType messageType;
  final int? audioDuration;
  final DateTime createdAt;

  // Edit
  final bool isEdited;
  final DateTime? editedAt;

  // Delete
  final bool deletedForAll;
  final List<String> deletedForMe; // list of userIds

  // Reply
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;

  // Forward
  final String? forwardedFromGroupId;
  final String? forwardedFromSenderId;

  // Read receipts — Map<userId, timestamp>
  final Map<String, DateTime> seenBy;
  final Map<String, DateTime> deliveredTo;
  final Map<String, DateTime> listenedBy;

  // Reactions — Map<userId, emoji>
  final Map<String, String> reactions;

  // Mentions
  final List<String> mentionedUserIds;

  // System message (e.g. "John joined the group")
  final String? systemText;

  static const deleteCutoffMinutes = 10;

  const GroupMessageEntity({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.text,
    this.mediaUrls = const [],
    this.messageType = GroupMessageType.text,
    this.audioDuration,
    required this.createdAt,
    this.isEdited = false,
    this.editedAt,
    this.deletedForAll = false,
    this.deletedForMe = const [],
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderId,
    this.replyToSenderName,
    this.forwardedFromGroupId,
    this.forwardedFromSenderId,
    this.seenBy = const {},
    this.deliveredTo = const {},
    this.listenedBy = const {},
    this.reactions = const {},
    this.mentionedUserIds = const [],
    this.systemText,
  });

  /// Whether the current user can delete for everyone (10-min window).
  bool canDeleteForEveryone(String myUid) {
    if (senderId != myUid) return false;
    final age = DateTime.now().difference(createdAt);
    return age.inMinutes < deleteCutoffMinutes;
  }

  bool isDeletedForUser(String uid) =>
      deletedForAll || deletedForMe.contains(uid);

  bool isSeenBy(String uid) => seenBy.containsKey(uid);
  bool isListenedBy(String uid) => listenedBy.containsKey(uid);

  GroupMessageEntity copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? senderAvatarUrl,
    String? text,
    List<String>? mediaUrls,
    GroupMessageType? messageType,
    int? audioDuration,
    DateTime? createdAt,
    bool? isEdited,
    DateTime? editedAt,
    bool? deletedForAll,
    List<String>? deletedForMe,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderId,
    String? replyToSenderName,
    String? forwardedFromGroupId,
    String? forwardedFromSenderId,
    Map<String, DateTime>? seenBy,
    Map<String, DateTime>? deliveredTo,
    Map<String, DateTime>? listenedBy,
    Map<String, String>? reactions,
    List<String>? mentionedUserIds,
    String? systemText,
  }) {
    return GroupMessageEntity(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      messageType: messageType ?? this.messageType,
      audioDuration: audioDuration ?? this.audioDuration,
      createdAt: createdAt ?? this.createdAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      deletedForAll: deletedForAll ?? this.deletedForAll,
      deletedForMe: deletedForMe ?? this.deletedForMe,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToText: replyToText ?? this.replyToText,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      forwardedFromGroupId: forwardedFromGroupId ?? this.forwardedFromGroupId,
      forwardedFromSenderId:
          forwardedFromSenderId ?? this.forwardedFromSenderId,
      seenBy: seenBy ?? this.seenBy,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      listenedBy: listenedBy ?? this.listenedBy,
      reactions: reactions ?? this.reactions,
      mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
      systemText: systemText ?? this.systemText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        senderId,
        text,
        mediaUrls,
        messageType,
        createdAt,
        isEdited,
        deletedForAll,
        deletedForMe,
        seenBy,
        listenedBy,
        reactions,
      ];
}
