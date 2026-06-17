import 'package:equatable/equatable.dart';

/// Who is allowed to send messages inside the group.
enum WhoCanSend { everyone, adminsOnly }

/// Core domain entity for a Group (Community).
/// Pure Dart — no Firebase imports.
class GroupEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final List<String> activeMembers;
  final DateTime createdAt;

  // Last message preview (for list tile)
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageAt;

  // Settings
  final bool isPublic;
  final String? inviteLink;
  final String? pinnedMessageId;
  final WhoCanSend whoCanSend;

  // Community relationship
  /// Non-null when this group belongs to a Community.
  final String? communityId;

  /// True for the announcement channel inside a Community.
  /// When true, only community admins / superAdmins can send messages
  /// (enforced by whoCanSend = WhoCanSend.adminsOnly at creation).
  final bool isAnnouncementOnly;

  // Unread per user — Map<userId, count>
  final Map<String, int> unreadCount;

  const GroupEntity({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.ownerId,
    required this.adminIds,
    required this.memberIds,
    required this.activeMembers,
    required this.createdAt,
    this.lastMessage = '',
    this.lastMessageSenderId = '',
    this.lastMessageAt,
    this.isPublic = false,
    this.inviteLink,
    this.pinnedMessageId,
    this.whoCanSend = WhoCanSend.everyone,
    this.unreadCount = const {},
    this.communityId,
    this.isAnnouncementOnly = false,
  });

  bool isOwner(String uid) => ownerId == uid;
  bool isAdmin(String uid) => adminIds.contains(uid) || ownerId == uid;
  bool isMember(String uid) => memberIds.contains(uid);
  bool isActiveMember(String uid) => activeMembers.contains(uid);
  bool canSend(String uid) =>
      isActiveMember(uid) && (whoCanSend == WhoCanSend.everyone || isAdmin(uid));

  int myUnread(String uid) => unreadCount[uid] ?? 0;

  GroupEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? ownerId,
    List<String>? adminIds,
    List<String>? memberIds,
    List<String>? activeMembers,
    DateTime? createdAt,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    bool? isPublic,
    String? inviteLink,
    String? pinnedMessageId,
    WhoCanSend? whoCanSend,
    Map<String, int>? unreadCount,
    Object? communityId = _sentinel,
    bool? isAnnouncementOnly,
  }) {
    return GroupEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      adminIds: adminIds ?? this.adminIds,
      memberIds: memberIds ?? this.memberIds,
      activeMembers: activeMembers ?? this.activeMembers,
      createdAt: createdAt ?? this.createdAt,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isPublic: isPublic ?? this.isPublic,
      inviteLink: inviteLink ?? this.inviteLink,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      whoCanSend: whoCanSend ?? this.whoCanSend,
      unreadCount: unreadCount ?? this.unreadCount,
      communityId: communityId == _sentinel ? this.communityId : communityId as String?,
      isAnnouncementOnly: isAnnouncementOnly ?? this.isAnnouncementOnly,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        ownerId,
        adminIds,
        memberIds,
        activeMembers,
        createdAt,
        lastMessage,
        lastMessageAt,
        isPublic,
        inviteLink,
        pinnedMessageId,
        whoCanSend,
        unreadCount,
        communityId,
        isAnnouncementOnly,
      ];
}

// Sentinel object to distinguish "not passed" from explicit null in copyWith.
const Object _sentinel = Object();
