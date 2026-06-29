import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_test2/features/community/domain/repositories/group_join_request_repository.dart';
import 'package:project_test2/features/community/domain/repositories/group_invite_repository.dart';
import 'package:project_test2/features/community/domain/repositories/group_repository.dart';
import 'package:project_test2/features/community/domain/entities/group_invite_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';
import 'package:project_test2/features/community/presentation/bloc/group_join_request/group_join_request_event.dart';
import 'package:project_test2/features/community/presentation/bloc/group_join_request/group_join_request_state.dart';

class GroupJoinRequestBloc extends Bloc<GroupJoinRequestEvent, GroupJoinRequestState> {
  final GroupJoinRequestRepository _joinRequestRepository;
  final GroupInviteRepository _inviteRepository;
  final GroupRepository _groupRepository;

  GroupJoinRequestBloc({
    required GroupJoinRequestRepository joinRequestRepository,
    required GroupInviteRepository inviteRepository,
    required GroupRepository groupRepository,
  })  : _joinRequestRepository = joinRequestRepository,
        _inviteRepository = inviteRepository,
        _groupRepository = groupRepository,
        super(GroupJoinRequestInitial()) {
    on<LoadJoinRequestByToken>(_onLoadJoinRequestByToken);
    on<SubmitJoinRequest>(_onSubmitJoinRequest);
    on<LoadGroupJoinRequests>(_onLoadGroupJoinRequests);
    on<UpdateJoinRequestStatus>(_onUpdateJoinRequestStatus);
  }

  Future<void> _onLoadJoinRequestByToken(LoadJoinRequestByToken event, Emitter<GroupJoinRequestState> emit) async {
    emit(GroupJoinRequestLoading());
    try {
      final invite = await _inviteRepository.getInvite(event.token);
      if (invite != null) {
        if (!invite.isValid(DateTime.now())) {
          emit(const GroupJoinRequestError('Invite link has expired or is invalid.'));
        } else {
          final group = await _groupRepository.getGroup(invite.groupId);
          if (group != null) {
            emit(GroupJoinRequestTokenLoaded(invite, group));
          } else {
            emit(const GroupJoinRequestError('The group you are trying to join does not exist.'));
          }
        }
      } else {
        final legacyGroup = await _groupRepository.getGroupByInviteLink(event.token);
        if (legacyGroup == null) {
          emit(const GroupJoinRequestError('Invalid invite link'));
          return;
        }

        final syntheticInvite = GroupInviteEntity(
          inviteToken: event.token,
          groupId: legacyGroup.id,
          creatorId: legacyGroup.ownerId,
          createdAt: legacyGroup.createdAt,
          requiresApproval: !legacyGroup.isPublic,
          isRevoked: false,
        );
        emit(GroupJoinRequestTokenLoaded(syntheticInvite, legacyGroup));
      }
    } catch (e) {
      emit(GroupJoinRequestError('Failed to load invite: ${e.toString()}'));
    }
  }

  Future<void> _onSubmitJoinRequest(SubmitJoinRequest event, Emitter<GroupJoinRequestState> emit) async {
    emit(GroupJoinRequestLoading());
    try {
      GroupInviteEntity? invite = await _inviteRepository.getInvite(event.inviteToken);
      var group = invite != null ? await _groupRepository.getGroup(invite.groupId) : null;

      if (invite == null || group == null) {
        final legacyGroup = await _groupRepository.getGroupByInviteLink(event.inviteToken);
        if (legacyGroup == null) throw Exception('Invalid invite link');

        group = legacyGroup;
        invite = GroupInviteEntity(
          inviteToken: event.inviteToken,
          groupId: legacyGroup.id,
          creatorId: legacyGroup.ownerId,
          createdAt: legacyGroup.createdAt,
          requiresApproval: !legacyGroup.isPublic,
          isRevoked: false,
        );
      }

      final userName = event.metadata?['name'] ?? 'Unknown User';
      final avatarUrl = event.metadata?['avatarUrl'];

      // If invite does not require approval and group is public, join directly!
      if (!invite.requiresApproval && group.isPublic) {
        await _groupRepository.joinViaInviteLink(
          groupId: group.id,
          userId: event.userId,
          userName: userName,
          userAvatarUrl: avatarUrl,
        );
        emit(GroupJoinRequestSubmitted(
          GroupJoinRequestEntity(
            requestId: 'direct_join',
            groupId: group.id,
            groupName: group.name,
            groupImageUrl: group.imageUrl,
            userId: event.userId,
            userName: userName,
            userAvatarUrl: avatarUrl,
            requestedAt: DateTime.now(),
            status: GroupJoinRequestStatus.approved,
          ),
        ));
      } else {
        // Submit request to Firestore
        await _joinRequestRepository.submitRequest(
          groupId: group.id,
          groupName: group.name,
          groupImageUrl: group.imageUrl,
          userId: event.userId,
          userName: userName,
          userAvatarUrl: avatarUrl,
          inviteToken: event.inviteToken,
        );
        
        emit(GroupJoinRequestSubmitted(
          GroupJoinRequestEntity(
            requestId: 'pending_request',
            groupId: group.id,
            groupName: group.name,
            groupImageUrl: group.imageUrl,
            userId: event.userId,
            userName: userName,
            userAvatarUrl: avatarUrl,
            requestedAt: DateTime.now(),
            status: GroupJoinRequestStatus.pending,
          ),
        ));
      }
    } catch (e) {
      emit(GroupJoinRequestError('Failed to submit request: ${e.toString()}'));
    }
  }

  Future<void> _onLoadGroupJoinRequests(LoadGroupJoinRequests event, Emitter<GroupJoinRequestState> emit) async {
    emit(GroupJoinRequestLoading());
    try {
      final requestsStream = _joinRequestRepository.watchPendingRequests(event.groupId);
      await emit.forEach<List<GroupJoinRequestEntity>>(
        requestsStream,
        onData: (requests) => GroupJoinRequestsLoaded(requests),
        onError: (error, stackTrace) => GroupJoinRequestError(error.toString()),
      );
    } catch (e) {
      emit(GroupJoinRequestError('Failed to load requests: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateJoinRequestStatus(UpdateJoinRequestStatus event, Emitter<GroupJoinRequestState> emit) async {
    try {
      if (event.status == GroupJoinRequestStatus.approved) {
        await _joinRequestRepository.approveRequest(
          requestId: event.requestId,
          groupId: event.groupId,
          userId: event.userId,
          userName: event.userName,
          userAvatarUrl: event.userAvatarUrl,
        );
      } else if (event.status == GroupJoinRequestStatus.rejected) {
        await _joinRequestRepository.rejectRequest(requestId: event.requestId);
      }
      emit(GroupJoinRequestStatusUpdated('Request ${event.status.name} successfully'));
    } catch (e) {
      emit(GroupJoinRequestError('Failed to update request: ${e.toString()}'));
    }
  }
}
