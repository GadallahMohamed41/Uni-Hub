import 'package:equatable/equatable.dart';

/// Role of a member inside a group.
enum GroupRole { owner, admin, member }

/// Domain entity for a single group member.
class GroupMemberEntity extends Equatable {
  final String userId;
  final String name;
  final String? avatarUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime? muteUntil; // null = not muted

  const GroupMemberEntity({
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.isOnline = false,
    this.lastSeen,
    this.muteUntil,
  });

  bool get isMuted =>
      muteUntil != null && muteUntil!.isAfter(DateTime.now());

  GroupMemberEntity copyWith({
    String? userId,
    String? name,
    String? avatarUrl,
    GroupRole? role,
    DateTime? joinedAt,
    bool? isOnline,
    DateTime? lastSeen,
    DateTime? muteUntil,
  }) {
    return GroupMemberEntity(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      muteUntil: muteUntil ?? this.muteUntil,
    );
  }

  @override
  List<Object?> get props => [
        userId,
        name,
        avatarUrl,
        role,
        joinedAt,
        isOnline,
        lastSeen,
        muteUntil,
      ];
}
