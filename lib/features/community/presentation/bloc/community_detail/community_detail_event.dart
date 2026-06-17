import 'package:equatable/equatable.dart';
import '../../../domain/entities/group_entity.dart';
import '../../../domain/entities/community_member_entity.dart';
import '../../../domain/entities/join_request_entity.dart';

abstract class CommunityDetailEvent extends Equatable {
  const CommunityDetailEvent();
  @override
  List<Object?> get props => [];
}

/// Start watching a community's groups, members, and join requests.
class CommunityDetailStarted extends CommunityDetailEvent {
  final String communityId;
  final String currentUserId;
  const CommunityDetailStarted(
      {required this.communityId, required this.currentUserId});
  @override
  List<Object?> get props => [communityId, currentUserId];
}

// ── Internal stream events ───────────────────────────────────────────────────

class CommunityDetailGroupsUpdated extends CommunityDetailEvent {
  final List<GroupEntity> groups;
  const CommunityDetailGroupsUpdated(this.groups);
  @override
  List<Object?> get props => [groups];
}

class CommunityDetailMembersUpdated extends CommunityDetailEvent {
  final List<CommunityMemberEntity> members;
  const CommunityDetailMembersUpdated(this.members);
  @override
  List<Object?> get props => [members];
}

class CommunityDetailRequestsUpdated extends CommunityDetailEvent {
  final List<JoinRequestEntity> requests;
  const CommunityDetailRequestsUpdated(this.requests);
  @override
  List<Object?> get props => [requests];
}

class CommunityDetailStreamError extends CommunityDetailEvent {
  final String message;
  const CommunityDetailStreamError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── Group management ─────────────────────────────────────────────────────────

class CommunityDetailCreateGroup extends CommunityDetailEvent {
  final String communityId;
  final String name;
  final String description;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final String? imageUrl;

  const CommunityDetailCreateGroup({
    required this.communityId,
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    this.imageUrl,
  });

  @override
  List<Object?> get props => [communityId, name, ownerId];
}

class CommunityDetailAddExistingGroup extends CommunityDetailEvent {
  final String communityId;
  final String groupId;
  const CommunityDetailAddExistingGroup(
      {required this.communityId, required this.groupId});
  @override
  List<Object?> get props => [communityId, groupId];
}

class CommunityDetailRemoveGroup extends CommunityDetailEvent {
  final String groupId;
  const CommunityDetailRemoveGroup(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

// ── Member management ────────────────────────────────────────────────────────

class CommunityDetailRemoveMember extends CommunityDetailEvent {
  final String communityId;
  final String targetUserId;
  final String actorId;
  const CommunityDetailRemoveMember({
    required this.communityId,
    required this.targetUserId,
    required this.actorId,
  });
  @override
  List<Object?> get props => [communityId, targetUserId];
}

class CommunityDetailPromoteAdmin extends CommunityDetailEvent {
  final String communityId;
  final String targetUserId;
  final String actorId;
  const CommunityDetailPromoteAdmin({
    required this.communityId,
    required this.targetUserId,
    required this.actorId,
  });
  @override
  List<Object?> get props => [communityId, targetUserId];
}

class CommunityDetailDemoteAdmin extends CommunityDetailEvent {
  final String communityId;
  final String targetUserId;
  final String actorId;
  const CommunityDetailDemoteAdmin({
    required this.communityId,
    required this.targetUserId,
    required this.actorId,
  });
  @override
  List<Object?> get props => [communityId, targetUserId];
}

// ── Join request management ──────────────────────────────────────────────────

class CommunityDetailApproveRequest extends CommunityDetailEvent {
  final String communityId;
  final String requestId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String actorId;

  const CommunityDetailApproveRequest({
    required this.communityId,
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.actorId,
  });
  @override
  List<Object?> get props => [communityId, requestId, userId];
}

class CommunityDetailDenyRequest extends CommunityDetailEvent {
  final String communityId;
  final String requestId;
  final String actorId;
  const CommunityDetailDenyRequest({
    required this.communityId,
    required this.requestId,
    required this.actorId,
  });
  @override
  List<Object?> get props => [communityId, requestId];
}

class CommunityDetailErrorCleared extends CommunityDetailEvent {
  const CommunityDetailErrorCleared();
}

