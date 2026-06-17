import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/community_entity.dart';
import '../../../domain/repositories/community_repository.dart';
import 'community_list_event.dart';
import 'community_list_state.dart';

class CommunityListBloc
    extends Bloc<CommunityListEvent, CommunityListState> {
  CommunityListBloc({required CommunityRepository repository})
      : _repo = repository,
        super(const CommunityListInitial()) {
    on<CommunityListStarted>(_onStarted);
    on<CommunityListUpdated>(_onUpdated);
    on<CommunityListStreamError>(_onStreamError);
    on<CommunityListCreateCommunity>(_onCreateCommunity);
    on<CommunityListJoinViaLink>(_onJoinViaLink);
    on<CommunityListLeaveCommunity>(_onLeave);
    on<CommunityListDeleteCommunity>(_onDelete);
    on<CommunityListErrorCleared>(_onErrorCleared);
    on<CommunityListNewlyCreatedCleared>(_onNewlyCreatedCleared);
  }

  final CommunityRepository _repo;
  StreamSubscription? _communitiesSub;

  Future<void> _onStarted(
      CommunityListStarted event, Emitter<CommunityListState> emit) async {
    emit(const CommunityListLoading());
    await _communitiesSub?.cancel();

    _communitiesSub = _repo.watchUserCommunities(event.userId).listen(
          (list) => add(CommunityListUpdated(list)),
          onError: (e, st) {
            debugPrint('[CommunityListBloc] Stream error: $e\n$st');
            add(CommunityListStreamError(e.toString()));
          },
        );
  }

  void _onUpdated(
      CommunityListUpdated event, Emitter<CommunityListState> emit) {
    final current = state;
    if (current is CommunityListLoaded) {
      emit(current.copyWith(communities: event.communities));
    } else {
      emit(CommunityListLoaded(communities: event.communities));
    }
  }

  void _onStreamError(
      CommunityListStreamError event, Emitter<CommunityListState> emit) {
    emit(CommunityListError(event.message));
  }

  Future<void> _onCreateCommunity(CommunityListCreateCommunity event,
      Emitter<CommunityListState> emit) async {
    // Get the current communities list (may be empty if stream hasn't loaded yet)
    final currentCommunities = state is CommunityListLoaded
        ? (state as CommunityListLoaded).communities
        : <CommunityEntity>[];

    // Always emit isCreating=true so the UI spinner works regardless of prior state
    emit(CommunityListLoaded(
      communities: List<CommunityEntity>.from(currentCommunities),
      isCreating: true,
    ));

    try {
      final community = await _repo.createCommunity(
        name: event.name,
        description: event.description,
        createdBy: event.createdBy,
        creatorName: event.creatorName,
        creatorAvatarUrl: event.creatorAvatarUrl,
        imageUrl: event.imageUrl,
        isPublic: event.isPublic,
      );
      final loaded = state is CommunityListLoaded
          ? state as CommunityListLoaded
          : CommunityListLoaded(communities: List<CommunityEntity>.from(currentCommunities));
      emit(loaded.copyWith(isCreating: false, newlyCreated: community));
    } catch (e) {
      debugPrint('[CommunityListBloc] createCommunity error: $e');
      final loaded = state is CommunityListLoaded
          ? state as CommunityListLoaded
          : CommunityListLoaded(communities: List<CommunityEntity>.from(currentCommunities));
      emit(loaded.copyWith(isCreating: false, error: e.toString()));
    }
  }

  Future<void> _onJoinViaLink(CommunityListJoinViaLink event,
      Emitter<CommunityListState> emit) async {
    try {
      final community =
          await _repo.getCommunityByInviteLink(event.inviteLink);
      if (community == null) {
        // Not a community token (may be a standalone group link — handled elsewhere).
        return;
      }

      // Check if already a member
      final member = await _repo.getMember(
          communityId: community.id, userId: event.userId);
      if (member != null) {
        if (state is CommunityListLoaded) {
          emit((state as CommunityListLoaded).copyWith(
              error: 'You have already joined this community.'));
        }
        return;
      }

      if (community.isPublic) {
        await _repo.joinCommunity(
          communityId: community.id,
          userId: event.userId,
          userName: event.userName,
          userAvatarUrl: event.userAvatarUrl,
        );
      } else {
        await _repo.requestToJoinCommunity(
          communityId: community.id,
          userId: event.userId,
          userName: event.userName,
          userAvatarUrl: event.userAvatarUrl,
        );
        if (state is CommunityListLoaded) {
          emit((state as CommunityListLoaded).copyWith(
              error: 'Join request sent — awaiting admin approval'));
        }
      }
    } catch (e) {
      if (state is CommunityListLoaded) {
        emit(
            (state as CommunityListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _onLeave(CommunityListLeaveCommunity event,
      Emitter<CommunityListState> emit) async {
    try {
      await _repo.leaveCommunity(
          communityId: event.communityId, userId: event.userId);
    } catch (e) {
      if (state is CommunityListLoaded) {
        emit((state as CommunityListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  Future<void> _onDelete(CommunityListDeleteCommunity event,
      Emitter<CommunityListState> emit) async {
    try {
      await _repo.deleteCommunity(
          communityId: event.communityId, actorId: event.actorId);
    } catch (e) {
      if (state is CommunityListLoaded) {
        emit((state as CommunityListLoaded).copyWith(error: e.toString()));
      }
    }
  }

  void _onErrorCleared(
      CommunityListErrorCleared event, Emitter<CommunityListState> emit) {
    if (state is CommunityListLoaded) {
      emit((state as CommunityListLoaded).copyWith(error: null));
    }
  }

  void _onNewlyCreatedCleared(
      CommunityListNewlyCreatedCleared event, Emitter<CommunityListState> emit) {
    if (state is CommunityListLoaded) {
      emit((state as CommunityListLoaded).copyWith(newlyCreated: null));
    }
  }

  @override
  Future<void> close() {
    _communitiesSub?.cancel();
    return super.close();
  }
}

