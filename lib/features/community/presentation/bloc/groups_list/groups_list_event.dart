import 'package:equatable/equatable.dart';
import '../../../domain/entities/group_entity.dart';

abstract class GroupsListEvent extends Equatable {
  const GroupsListEvent();
  @override
  List<Object?> get props => [];
}

class GroupsListStarted extends GroupsListEvent {
  final String userId;
  const GroupsListStarted(this.userId);
  @override
  List<Object?> get props => [userId];
}

class GroupsListUpdated extends GroupsListEvent {
  final List<GroupEntity> groups;
  const GroupsListUpdated(this.groups);
  @override
  List<Object?> get props => [groups];
}

class GroupsListCreateGroup extends GroupsListEvent {
  final String name;
  final String description;
  final String ownerId;
  final String ownerName;
  final String? ownerAvatarUrl;
  final List<String> initialMemberIds;
  final String? imageUrl;
  final bool isPublic;

  const GroupsListCreateGroup({
    required this.name,
    required this.description,
    required this.ownerId,
    required this.ownerName,
    this.ownerAvatarUrl,
    required this.initialMemberIds,
    this.imageUrl,
    this.isPublic = false,
  });

  @override
  List<Object?> get props =>
      [name, description, ownerId, initialMemberIds, imageUrl, isPublic];
}

class GroupsListJoinViaLink extends GroupsListEvent {
  final String inviteLink;
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  const GroupsListJoinViaLink({
    required this.inviteLink,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  });

  @override
  List<Object?> get props => [inviteLink, userId];
}

class GroupsListLeaveGroup extends GroupsListEvent {
  final String groupId;
  final String userId;
  const GroupsListLeaveGroup({required this.groupId, required this.userId});
  @override
  List<Object?> get props => [groupId, userId];
}

class GroupsListDeleteGroup extends GroupsListEvent {
  final String groupId;
  const GroupsListDeleteGroup(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

class GroupsListMuteGroup extends GroupsListEvent {
  final String groupId;
  final String userId;
  final DateTime muteUntil;
  const GroupsListMuteGroup({
    required this.groupId,
    required this.userId,
    required this.muteUntil,
  });
  @override
  List<Object?> get props => [groupId, userId, muteUntil];
}

class GroupsListStreamError extends GroupsListEvent {
  final String message;
  const GroupsListStreamError(this.message);
  @override
  List<Object?> get props => [message];
}

class GroupsListErrorCleared extends GroupsListEvent {
  const GroupsListErrorCleared();
}

class GroupsListNewlyCreatedCleared extends GroupsListEvent {
  const GroupsListNewlyCreatedCleared();
}

