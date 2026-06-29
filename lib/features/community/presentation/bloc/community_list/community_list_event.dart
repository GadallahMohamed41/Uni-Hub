import 'package:equatable/equatable.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';

abstract class CommunityListEvent extends Equatable {
  const CommunityListEvent();
  @override
  List<Object?> get props => [];
}

/// Start listening to communities for [userId].
class CommunityListStarted extends CommunityListEvent {
  final String userId;
  const CommunityListStarted(this.userId);
  @override
  List<Object?> get props => [userId];
}

/// Internal: stream emitted a new list.
class CommunityListUpdated extends CommunityListEvent {
  final List<CommunityEntity> communities;
  const CommunityListUpdated(this.communities);
  @override
  List<Object?> get props => [communities];
}

/// Create a new community.
class CommunityListCreateCommunity extends CommunityListEvent {
  final String name;
  final String description;
  final String createdBy;
  final String creatorName;
  final String? creatorAvatarUrl;
  final String? imageUrl;
  final bool isPublic;

  const CommunityListCreateCommunity({
    required this.name,
    required this.description,
    required this.createdBy,
    required this.creatorName,
    this.creatorAvatarUrl,
    this.imageUrl,
    this.isPublic = true,
  });

  @override
  List<Object?> get props =>
      [name, description, createdBy, imageUrl, isPublic];
}

/// Join a community using its invite link token.
class CommunityListJoinViaLink extends CommunityListEvent {
  final String inviteLink;
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  const CommunityListJoinViaLink({
    required this.inviteLink,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  });

  @override
  List<Object?> get props => [inviteLink, userId];
}

/// Leave a community.
class CommunityListLeaveCommunity extends CommunityListEvent {
  final String communityId;
  final String userId;
  const CommunityListLeaveCommunity(
      {required this.communityId, required this.userId});
  @override
  List<Object?> get props => [communityId, userId];
}

/// Delete a community (superAdmin only).
class CommunityListDeleteCommunity extends CommunityListEvent {
  final String communityId;
  final String actorId;
  const CommunityListDeleteCommunity(
      {required this.communityId, required this.actorId});
  @override
  List<Object?> get props => [communityId, actorId];
}

/// Internal: stream error forwarded as an event.
class CommunityListStreamError extends CommunityListEvent {
  final String message;
  const CommunityListStreamError(this.message);
  @override
  List<Object?> get props => [message];
}

/// Clear the transient error from the loaded state.
class CommunityListErrorCleared extends CommunityListEvent {
  const CommunityListErrorCleared();
}

/// Clear the newly created community from the loaded state.
class CommunityListNewlyCreatedCleared extends CommunityListEvent {
  const CommunityListNewlyCreatedCleared();
}

