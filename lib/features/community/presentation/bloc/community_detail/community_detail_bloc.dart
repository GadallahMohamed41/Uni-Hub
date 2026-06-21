import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/repositories/community_repository.dart';
import '../../../domain/entities/community_entity.dart';
import '../../../domain/entities/community_member_entity.dart';
import 'community_detail_event.dart';
import 'community_detail_state.dart';

class CommunityDetailBloc
    extends Bloc<CommunityDetailEvent, CommunityDetailState> {
  CommunityDetailBloc({
    required CommunityRepository repository,
    required CommunityEntity community,
    required String currentUserId,
  })  : _repo = repository,
        _community = community,
        _currentUserId = currentUserId,
        super(const CommunityDetailLoading()) {
    on<CommunityDetailStarted>(_onStarted);
    on<CommunityDetailGroupsUpdated>(_onGroupsUpdated);
    on<CommunityDetailMembersUpdated>(_onMembersUpdated);
    on<CommunityDetailRequestsUpdated>(_onRequestsUpdated);
    on<CommunityDetailStreamError>(_onStreamError);
    on<CommunityDetailCreateGroup>(_onCreateGroup);
    on<CommunityDetailAddExistingGroup>(_onAddExistingGroup);
    on<CommunityDetailRemoveGroup>(_onRemoveGroup);
    on<CommunityDetailRemoveMember>(_onRemoveMember);
    on<CommunityDetailPromoteAdmin>(_onPromoteAdmin);
    on<CommunityDetailDemoteAdmin>(_onDemoteAdmin);
    on<CommunityDetailApproveRequest>(_onApproveRequest);
    on<CommunityDetailDenyRequest>(_onDenyRequest);
    on<CommunityDetailErrorCleared>(_onErrorCleared);

    // Auto-start
    add(CommunityDetailStarted(
        communityId: community.id, currentUserId: currentUserId));
  }

  final CommunityRepository _repo;
  final CommunityEntity _community;
  final String _currentUserId;

  StreamSubscription? _groupsSub;
  StreamSubscription? _membersSub;
  StreamSubscription? _requestsSub;

  Future<void> _onStarted(CommunityDetailStarted event,
      Emitter<CommunityDetailState> emit) async {
    await _groupsSub?.cancel();
    await _membersSub?.cancel();
    await _requestsSub?.cancel();

    // Fetch current user's membership
    final currentMember = await _repo.getMember(
        communityId: event.communityId, userId: event.currentUserId);

    emit(CommunityDetailLoaded(
      community: _community,
      currentMember: currentMember,
    ));

    // Subscribe to groups
    _groupsSub = _repo
        .watchCommunityGroups(event.communityId)
        .listen(
          (groups) => add(CommunityDetailGroupsUpdated(groups)),
          onError: (e) => add(CommunityDetailStreamError(e.toString())),
        );

    // Subscribe to members
    _membersSub = _repo
        .watchCommunityMembers(event.communityId)
        .listen(
          (members) => add(CommunityDetailMembersUpdated(members)),
          onError: (e) => add(CommunityDetailStreamError(e.toString())),
        );

    // Subscribe to join requests (only relevant for admins)
    if (currentMember?.isAdmin ?? false) {
      _requestsSub = _repo
          .watchJoinRequests(event.communityId)
          .listen(
            (requests) => add(CommunityDetailRequestsUpdated(requests)),
            onError: (e) => add(CommunityDetailStreamError(e.toString())),
          );
    }
  }

  void _onGroupsUpdated(CommunityDetailGroupsUpdated event,
      Emitter<CommunityDetailState> emit) {
    if (state is CommunityDetailLoaded) {
      emit((state as CommunityDetailLoaded).copyWith(groups: event.groups));
    }
  }

  void _onMembersUpdated(CommunityDetailMembersUpdated event,
      Emitter<CommunityDetailState> emit) {
    if (state is CommunityDetailLoaded) {
      // Refresh currentMember from the updated list
      final currentMember = event.members
          .where((m) => m.userId == _currentUserId)
          .cast<CommunityMemberEntity?>()
          .firstOrNull;
      emit((state as CommunityDetailLoaded)
          .copyWith(members: event.members, currentMember: currentMember));
    }
  }

  void _onRequestsUpdated(CommunityDetailRequestsUpdated event,
      Emitter<CommunityDetailState> emit) {
    if (state is CommunityDetailLoaded) {
      emit((state as CommunityDetailLoaded)
          .copyWith(joinRequests: event.requests));
    }
  }

  void _onStreamError(CommunityDetailStreamError event,
      Emitter<CommunityDetailState> emit) {
    debugPrint('[CommunityDetailBloc] Stream error: ${event.message}');
    if (state is CommunityDetailLoaded) {
      emit(
          (state as CommunityDetailLoaded).copyWith(error: event.message));
    } else {
      emit(CommunityDetailError(event.message));
    }
  }

  Future<void> _onCreateGroup(CommunityDetailCreateGroup event,
      Emitter<CommunityDetailState> emit) async {
    _setWorking(emit, true);
    try {
      await _repo.createGroupInCommunity(
        communityId: event.communityId,
        name: event.name,
        description: event.description,
        ownerId: event.ownerId,
        ownerName: event.ownerName,
        ownerAvatarUrl: event.ownerAvatarUrl,
        imageUrl: event.imageUrl,
      );
      _setWorking(emit, false);
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onAddExistingGroup(CommunityDetailAddExistingGroup event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.addGroupToCommunity(
          communityId: event.communityId, groupId: event.groupId);
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onRemoveGroup(CommunityDetailRemoveGroup event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.removeGroupFromCommunity(groupId: event.groupId);
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onRemoveMember(CommunityDetailRemoveMember event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.removeCommunityMember(
        communityId: event.communityId,
        targetUserId: event.targetUserId,
        actorId: event.actorId,
      );
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onPromoteAdmin(CommunityDetailPromoteAdmin event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.promoteToCommunityAdmin(
        communityId: event.communityId,
        targetUserId: event.targetUserId,
        actorId: event.actorId,
      );
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onDemoteAdmin(CommunityDetailDemoteAdmin event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.demoteFromCommunityAdmin(
        communityId: event.communityId,
        targetUserId: event.targetUserId,
        actorId: event.actorId,
      );
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onApproveRequest(CommunityDetailApproveRequest event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.approveJoinRequest(
        communityId: event.communityId,
        requestId: event.requestId,
        userId: event.userId,
        userName: event.userName,
        userAvatarUrl: event.userAvatarUrl,
        actorId: event.actorId,
      );
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  Future<void> _onDenyRequest(CommunityDetailDenyRequest event,
      Emitter<CommunityDetailState> emit) async {
    try {
      await _repo.denyJoinRequest(
        communityId: event.communityId,
        requestId: event.requestId,
        actorId: event.actorId,
      );
    } catch (e) {
      _setWorking(emit, false, error: e.toString());
    }
  }

  void _onErrorCleared(CommunityDetailErrorCleared event,
      Emitter<CommunityDetailState> emit) {
    if (state is CommunityDetailLoaded) {
      emit((state as CommunityDetailLoaded).copyWith(error: null));
    }
  }

  void _setWorking(Emitter<CommunityDetailState> emit, bool isWorking,
      {String? error}) {
    if (state is CommunityDetailLoaded) {
      emit((state as CommunityDetailLoaded)
          .copyWith(isWorking: isWorking, error: error));
    }
  }

  @override
  Future<void> close() {
    _groupsSub?.cancel();
    _membersSub?.cancel();
    _requestsSub?.cancel();
    return super.close();
  }
}

