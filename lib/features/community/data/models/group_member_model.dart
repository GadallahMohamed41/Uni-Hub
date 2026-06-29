import 'package:cloud_firestore/cloud_firestore.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_member_entity.dart';
=======
import '../../domain/entities/group_member_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Firestore model for a group member document.
/// Stored at: groups/{groupId}/members/{userId}
class GroupMemberModel {
  final String userId;
  final String name;
  final String? avatarUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? muteUntil;

  const GroupMemberModel({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
    this.lastSeen,
    this.muteUntil,
  });

  factory GroupMemberModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupMemberModel(
      userId: doc.id,
      name: (d['name'] as String?) ?? '',
      avatarUrl: (d['avatarUrl'] as String?)?.trim(),
      role: _roleFromString(d['role'] as String?),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: (d['isOnline'] as bool?) ?? false,
      lastSeen: (d['lastSeen'] as Timestamp?)?.toDate(),
      muteUntil: (d['muteUntil'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'avatarUrl': avatarUrl,
        'role': _roleToString(role),
        'joinedAt': Timestamp.fromDate(joinedAt),
        'isOnline': isOnline,
        'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
        'muteUntil':
            muteUntil != null ? Timestamp.fromDate(muteUntil!) : null,
      };

  GroupMemberEntity toEntity() => GroupMemberEntity(
        userId: userId,
        name: name,
        avatarUrl: avatarUrl,
        role: role,
        joinedAt: joinedAt,
        isOnline: isOnline,
        lastSeen: lastSeen,
        muteUntil: muteUntil,
      );

  static GroupRole _roleFromString(String? s) {
    switch (s) {
      case 'owner':
        return GroupRole.owner;
      case 'admin':
        return GroupRole.admin;
      default:
        return GroupRole.member;
    }
  }

  static String _roleToString(GroupRole r) {
    switch (r) {
      case GroupRole.owner:
        return 'owner';
      case GroupRole.admin:
        return 'admin';
      case GroupRole.member:
        return 'member';
    }
  }
}
