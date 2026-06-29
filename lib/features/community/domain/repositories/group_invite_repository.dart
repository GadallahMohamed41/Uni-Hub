import 'package:project_test2/features/community/domain/entities/group_invite_entity.dart';

abstract class GroupInviteRepository {
  /// Create a new group invite token.
  Future<GroupInviteEntity> createInvite({
    required String groupId,
    required String creatorId,
    DateTime? expiresAt,
    int? maxUses,
    required bool requiresApproval,
  });

  /// Get the invite entity associated with a token.
  Future<GroupInviteEntity?> getInvite(String inviteToken);

  /// Revoke an active invite.
  Future<void> revokeInvite(String inviteToken);

  /// Record a usage of the invite.
  Future<void> incrementUseCount(String inviteToken);
}
