import 'package:equatable/equatable.dart';
<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_invite_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
=======
import '../../../domain/entities/group_join_request_entity.dart';
import '../../../domain/entities/group_invite_entity.dart';
import '../../../domain/entities/group_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class GroupJoinRequestState extends Equatable {
  const GroupJoinRequestState();

  @override
  List<Object?> get props => [];
}

class GroupJoinRequestInitial extends GroupJoinRequestState {}

class GroupJoinRequestLoading extends GroupJoinRequestState {}

class GroupJoinRequestTokenLoaded extends GroupJoinRequestState {
  final GroupInviteEntity invite;
  final GroupEntity group;
  const GroupJoinRequestTokenLoaded(this.invite, this.group);

  @override
  List<Object?> get props => [invite, group];
}

class GroupJoinRequestSubmitted extends GroupJoinRequestState {
  final GroupJoinRequestEntity request;
  const GroupJoinRequestSubmitted(this.request);

  @override
  List<Object?> get props => [request];
}

class GroupJoinRequestsLoaded extends GroupJoinRequestState {
  final List<GroupJoinRequestEntity> requests;
  const GroupJoinRequestsLoaded(this.requests);

  @override
  List<Object?> get props => [requests];
}

class GroupJoinRequestError extends GroupJoinRequestState {
  final String message;
  const GroupJoinRequestError(this.message);

  @override
  List<Object?> get props => [message];
}

class GroupJoinRequestStatusUpdated extends GroupJoinRequestState {
  final String message;
  const GroupJoinRequestStatusUpdated(this.message);

  @override
  List<Object?> get props => [message];
}
