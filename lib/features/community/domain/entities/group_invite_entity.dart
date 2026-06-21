import 'package:equatable/equatable.dart';

/// Represents a Group Invite token in the system.
class GroupInviteEntity extends Equatable {
  final String inviteToken;
  final String groupId;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxUses;
  final int useCount;
  final bool requiresApproval;
  final bool isRevoked;

  const GroupInviteEntity({
    required this.inviteToken,
    required this.groupId,
    required this.creatorId,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    this.requiresApproval = false,
    this.isRevoked = false,
  });

  /// Check if the invite link is valid under normal conditions.
  bool isValid(DateTime now) {
    if (isRevoked) return false;
    if (expiresAt != null && now.isAfter(expiresAt!)) return false;
    if (maxUses != null && useCount >= maxUses!) return false;
    return true;
  }

  @override
  List<Object?> get props => [
        inviteToken,
        groupId,
        creatorId,
        createdAt,
        expiresAt,
        maxUses,
        useCount,
        requiresApproval,
        isRevoked,
      ];
}
