import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';
=======
import '../../domain/entities/group_message_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Firestore model for a group message document.
/// Stored at: groups/{groupId}/messages/{messageId}
class GroupMessageModel {
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
  final bool isEdited;
  final DateTime? editedAt;
  final bool deletedForAll;
  final List<String> deletedForMe;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderId;
  final String? replyToSenderName;
  final String? forwardedFromGroupId;
  final String? forwardedFromSenderId;
  final Map<String, DateTime> seenBy;
  final Map<String, DateTime> deliveredTo;
  final Map<String, DateTime> listenedBy;
  final Map<String, String> reactions;
  final List<String> mentionedUserIds;
  final String? systemText;

  const GroupMessageModel({
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

  factory GroupMessageModel.fromFirestore(
      DocumentSnapshot doc, String groupId) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupMessageModel(
      id: doc.id,
      groupId: groupId,
      senderId: (d['senderId'] as String?) ?? '',
      senderName: (d['senderName'] as String?) ?? '',
      senderAvatarUrl: (d['senderAvatarUrl'] as String?)?.trim(),
      text: (d['text'] as String?) ?? '',
      mediaUrls: List<String>.from(d['mediaUrls'] ?? []),
      messageType: _typeFromString(d['messageType'] as String?),
      audioDuration: d['audioDuration'] as int?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: (d['isEdited'] as bool?) ?? false,
      editedAt: (d['editedAt'] as Timestamp?)?.toDate(),
      deletedForAll: (d['deletedForAll'] as bool?) ?? false,
      deletedForMe: List<String>.from(d['deletedForMe'] ?? []),
      replyToMessageId: d['replyToMessageId'] as String?,
      replyToText: d['replyToText'] as String?,
      replyToSenderId: d['replyToSenderId'] as String?,
      replyToSenderName: d['replyToSenderName'] as String?,
      forwardedFromGroupId: d['forwardedFromGroupId'] as String?,
      forwardedFromSenderId: d['forwardedFromSenderId'] as String?,
      seenBy: _parseTimestampMap(d['seenBy']),
      deliveredTo: _parseTimestampMap(d['deliveredTo']),
      listenedBy: _parseTimestampMap(d['listenedBy']),
      reactions: _parseStringMap(d['reactions']),
      mentionedUserIds: List<String>.from(d['mentionedUserIds'] ?? []),
      systemText: d['systemText'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatarUrl': senderAvatarUrl,
        'text': text,
        'mediaUrls': mediaUrls,
        'messageType': _typeToString(messageType),
        'audioDuration': audioDuration,
        'createdAt': Timestamp.fromDate(createdAt),
        'isEdited': isEdited,
        'editedAt': editedAt != null ? Timestamp.fromDate(editedAt!) : null,
        'deletedForAll': deletedForAll,
        'deletedForMe': deletedForMe,
        'replyToMessageId': replyToMessageId,
        'replyToText': replyToText,
        'replyToSenderId': replyToSenderId,
        'replyToSenderName': replyToSenderName,
        'forwardedFromGroupId': forwardedFromGroupId,
        'forwardedFromSenderId': forwardedFromSenderId,
        'seenBy': seenBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'deliveredTo':
            deliveredTo.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'listenedBy':
            listenedBy.map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'reactions': reactions,
        'mentionedUserIds': mentionedUserIds,
        'systemText': systemText,
      };

  GroupMessageEntity toEntity() => GroupMessageEntity(
        id: id,
        groupId: groupId,
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
        text: text,
        mediaUrls: mediaUrls,
        messageType: messageType,
        audioDuration: audioDuration,
        createdAt: createdAt,
        isEdited: isEdited,
        editedAt: editedAt,
        deletedForAll: deletedForAll,
        deletedForMe: deletedForMe,
        replyToMessageId: replyToMessageId,
        replyToText: replyToText,
        replyToSenderId: replyToSenderId,
        replyToSenderName: replyToSenderName,
        forwardedFromGroupId: forwardedFromGroupId,
        forwardedFromSenderId: forwardedFromSenderId,
        seenBy: seenBy,
        deliveredTo: deliveredTo,
        listenedBy: listenedBy,
        reactions: reactions,
        mentionedUserIds: mentionedUserIds,
        systemText: systemText,
      );

  // ── Helpers ────────────────────────────────────────────────────────────────

  static GroupMessageType _typeFromString(String? s) {
    switch (s) {
      case 'image':
        return GroupMessageType.image;
      case 'video':
        return GroupMessageType.video;
      case 'audio':
        return GroupMessageType.audio;
      case 'file':
        return GroupMessageType.file;
      case 'system':
        return GroupMessageType.system;
      default:
        return GroupMessageType.text;
    }
  }

  static String _typeToString(GroupMessageType t) {
    switch (t) {
      case GroupMessageType.image:
        return 'image';
      case GroupMessageType.video:
        return 'video';
      case GroupMessageType.audio:
        return 'audio';
      case GroupMessageType.file:
        return 'file';
      case GroupMessageType.system:
        return 'system';
      case GroupMessageType.text:
        return 'text';
    }
  }

  static Map<String, DateTime> _parseTimestampMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) => MapEntry(
          k.toString(),
          v is Timestamp ? v.toDate() : DateTime.now(),
        ));
  }

  static Map<String, String> _parseStringMap(dynamic raw) {
    if (raw == null || raw is! Map) return {};
    return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
  }
}
