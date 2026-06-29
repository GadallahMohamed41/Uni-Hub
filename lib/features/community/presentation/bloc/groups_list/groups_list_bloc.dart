import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/domain/repositories/group_repository.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_event.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_state.dart';

class GroupsListBloc extends Bloc<GroupsListEvent, GroupsListState> {
  GroupsListBloc({required GroupRepository repository})
      : _repo = repository,
        super(const GroupsListInitial()) {
    on<GroupsListStarted>(_onStarted);
    on<GroupsListUpdated>(_onUpdated);
    on<GroupsListStreamError>(_onStreamError);
    on<GroupsListCreateGroup>(_onCreateGroup);
    on<GroupsListJoinViaLink>(_onJoinViaLink);
    on<GroupsListLeaveGroup>(_onLeaveGroup);
    on<GroupsListDeleteGroup>(_onDeleteGroup);
    on<GroupsListMuteGroup>(_onMuteGroup);
    on<GroupsListErrorCleared>(_onErrorCleared);
    on<GroupsListNewlyCreatedCleared>(_onNewlyCreatedCleared);
  }

  final GroupRepository _repo;
  StreamSubscription? _groupsSub;

  Future<void> _onStarted(
      GroupsListStarted event, Emitter<GroupsListState> emit) async {
    emit(const GroupsListLoading());
    await _groupsSub?.cancel();

    _groupsSub = _repo.watchUserGroups(event.userId).listen(
          (groups) => add(GroupsListUpdated(groups)),
          onError: (e, st) {
            debugPrint('[GroupsListBloc] Stream error: $e\n$st');
            add(GroupsListStreamError(e.toString()));
          },
        );
  }

  void _onUpdated(
      GroupsListUpdated event, Emitter<GroupsListState> emit) {
    final current = state;
    if (current is GroupsListLoaded) {
      emit(current.copyWith(groups: event.groups));
    } else {
      emit(GroupsListLoaded(groups: event.groups));
    }
  }

  void _onStreamError(
      GroupsListStreamError event, Emitter<GroupsListState> emit) {
    debugPrint('[GroupsListBloc] Stream error: ${event.message}');
    emit(GroupsListError(event.message));
  }

  Future<void> _onCreateGroup(
      GroupsListCreateGroup event, Emitter<GroupsListState> emit) async {
    final currentGroups = state is GroupsListLoaded
        ? (state as GroupsListLoaded).groups
        : <GroupEntity>[];
    emit(GroupsListLoaded(
      groups: List.from(currentGroups),
      isCreating: true,
    ));
    try {
      final group = await _repo.createGroup(
        name: event.name,
        description: event.description,
        ownerId: event.ownerId,
        ownerName: event.ownerName,
        ownerAvatarUrl: event.ownerAvatarUrl,
        initialMemberIds: event.initialMemberIds,
        imageUrl: event.imageUrl,
        isPublic: event.isPublic,
      );
      emit(GroupsListLoaded(
        groups: List.from(currentGroups),
        isCreating: false,
        newlyCreatedGroup: group,
      ));
    } catch (e) {
      emit(GroupsListLoaded(
        groups: List.from(currentGroups),
        isCreating: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onJoinViaLink(
      GroupsListJoinViaLink event, Emitter<GroupsListState> emit) async {
    try {
      final group = await _repo.getGroupByInviteLink(event.inviteLink);
      if (group == null) {
        if (state is GroupsListLoaded) {
          emit((state as GroupsListLoaded)
              .copyWith(error: 'Invalid invite link'));
        }
        return;
      }
      if (group.isMember(event.userId)) {
        if (state is GroupsListLoaded) {
          emit((state as GroupsListLoaded).copyWith(
              error: 'You have already joined this group.'));
        }
        return;
      }
      await _repo.joinViaInviteLink(
        groupId: group.id,
        userId: event.userId,
        userName: event.userName,
        userAvatarUrl: event.userAvatarUrl,
      );
    } catch (e) {
      if (state is GroupsListLoaded) {
        emit((state as GroupsListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _onLeaveGroup(
      GroupsListLeaveGroup event, Emitter<GroupsListState> emit) async {
    try {
      await _repo.leaveGroup(
          groupId: event.groupId, userId: event.userId);
    } catch (e) {
      if (state is GroupsListLoaded) {
        emit((state as GroupsListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _onDeleteGroup(
      GroupsListDeleteGroup event, Emitter<GroupsListState> emit) async {
    try {
      await _repo.deleteGroup(event.groupId);
    } catch (e) {
      if (state is GroupsListLoaded) {
        emit((state as GroupsListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _onMuteGroup(
      GroupsListMuteGroup event, Emitter<GroupsListState> emit) async {
    try {
      await _repo.muteGroup(
        groupId: event.groupId,
        userId: event.userId,
        muteUntil: event.muteUntil,
      );
    } catch (e) {
      if (state is GroupsListLoaded) {
        emit((state as GroupsListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  void _onErrorCleared(
      GroupsListErrorCleared event, Emitter<GroupsListState> emit) {
    if (state is GroupsListLoaded) {
      emit((state as GroupsListLoaded).copyWith(error: null));
    }
  }

  void _onNewlyCreatedCleared(
      GroupsListNewlyCreatedCleared event, Emitter<GroupsListState> emit) {
    if (state is GroupsListLoaded) {
      emit((state as GroupsListLoaded).copyWith(newlyCreatedGroup: null));
    }
  }

  @override
  Future<void> close() {
    _groupsSub?.cancel();
    return super.close();
  }
}

