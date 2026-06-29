import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';
=======
import '../../../domain/entities/group_join_request_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class GroupJoinRequestEvent extends Equatable {
  const GroupJoinRequestEvent();

  @override
  List<Object?> get props => [];
}

class LoadJoinRequestByToken extends GroupJoinRequestEvent {
  final String token;
  const LoadJoinRequestByToken(this.token);

  @override
  List<Object?> get props => [token];
}

class SubmitJoinRequest extends GroupJoinRequestEvent {
  final String inviteToken;
  final String userId;
  final Map<String, dynamic>? metadata;

  const SubmitJoinRequest({
    required this.inviteToken,
    required this.userId,
    this.metadata,
  });

  @override
  List<Object?> get props => [inviteToken, userId, metadata];
}

class LoadGroupJoinRequests extends GroupJoinRequestEvent {
  final String groupId;
  final GroupJoinRequestStatus? status;

  const LoadGroupJoinRequests({required this.groupId, this.status});

  @override
  List<Object?> get props => [groupId, status];
}

class UpdateJoinRequestStatus extends GroupJoinRequestEvent {
  final String requestId;
  final GroupJoinRequestStatus status;
  final String groupId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;

  const UpdateJoinRequestStatus({
    required this.requestId, 
    required this.status,
    required this.groupId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
  });

  @override
  List<Object?> get props => [requestId, status, groupId, userId, userName, userAvatarUrl];
}
