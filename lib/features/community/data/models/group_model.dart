import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
=======
import '../../domain/entities/group_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Firestore-aware model that maps to/from [GroupEntity].
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String ownerId;
  final List<String> adminIds;
  final List<String> memberIds;
  final List<String> activeMembers;
  final DateTime createdAt;
  final String lastMessage;
  final String lastMessageSenderId;
  final DateTime? lastMessageAt;
  final bool isPublic;
  final String? inviteLink;
  final String? pinnedMessageId;
  final WhoCanSend whoCanSend;
  final Map<String, int> unreadCount;

  // Community relationship
  final String? communityId;
  final bool isAnnouncementOnly;

  const GroupModel({
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

  factory GroupModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupModel(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      imageUrl: (d['imageUrl'] as String?)?.trim(),
      ownerId: (d['ownerId'] as String?) ?? '',
      adminIds: List<String>.from(d['adminIds'] ?? []),
      memberIds: List<String>.from(d['memberIds'] ?? []),
      activeMembers: List<String>.from(d['activeMembers'] ?? d['memberIds'] ?? []),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessage: (d['lastMessage'] as String?) ?? '',
      lastMessageSenderId: (d['lastMessageSenderId'] as String?) ?? '',
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      isPublic: (d['isPublic'] as bool?) ?? false,
      inviteLink: d['inviteLink'] as String?,
      pinnedMessageId: d['pinnedMessageId'] as String?,
      whoCanSend: _whoCanSendFromString(d['whoCanSend'] as String?),
      unreadCount: _parseUnreadCount(d['unreadCount']),
      communityId: d['communityId'] as String?,
      isAnnouncementOnly: (d['isAnnouncementOnly'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'ownerId': ownerId,
        'adminIds': adminIds,
        'memberIds': memberIds,
        'activeMembers': activeMembers,
        'createdAt': Timestamp.fromDate(createdAt),
        'lastMessage': lastMessage,
        'lastMessageSenderId': lastMessageSenderId,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'isPublic': isPublic,
        'inviteLink': inviteLink,
        'pinnedMessageId': pinnedMessageId,
        'whoCanSend': _whoCanSendToString(whoCanSend),
        'unreadCount': unreadCount,
        'communityId': communityId,
        'isAnnouncementOnly': isAnnouncementOnly,
      };

  GroupEntity toEntity() => GroupEntity(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        ownerId: ownerId,
        adminIds: adminIds,
        memberIds: memberIds,
        activeMembers: activeMembers,
        createdAt: createdAt,
        lastMessage: lastMessage,
        lastMessageSenderId: lastMessageSenderId,
        lastMessageAt: lastMessageAt,
        isPublic: isPublic,
        inviteLink: inviteLink,
        pinnedMessageId: pinnedMessageId,
        whoCanSend: whoCanSend,
        unreadCount: unreadCount,
        communityId: communityId,
        isAnnouncementOnly: isAnnouncementOnly,
      );

  static WhoCanSend _whoCanSendFromString(String? v) {
    if (v == 'adminsOnly') return WhoCanSend.adminsOnly;
    return WhoCanSend.everyone;
  }

  static String _whoCanSendToString(WhoCanSend v) {
    switch (v) {
      case WhoCanSend.adminsOnly:
        return 'adminsOnly';
      case WhoCanSend.everyone:
        return 'everyone';
    }
  }

  static Map<String, int> _parseUnreadCount(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map) {
      return raw.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0));
    }
    return {};
  }
}
