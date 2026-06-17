import 'package:equatable/equatable.dart';
import '../../../domain/entities/community_entity.dart';
import '../../../domain/entities/community_member_entity.dart';
import '../../../domain/entities/join_request_entity.dart';
import '../../../domain/entities/group_entity.dart';

abstract class CommunityDetailState extends Equatable {
  const CommunityDetailState();
  @override
  List<Object?> get props => [];
}

class CommunityDetailInitial extends CommunityDetailState {
  const CommunityDetailInitial();
}

class CommunityDetailLoading extends CommunityDetailState {
  const CommunityDetailLoading();
}

class CommunityDetailLoaded extends CommunityDetailState {
  final CommunityEntity community;
  final List<GroupEntity> groups;
  final List<CommunityMemberEntity> members;
  final List<JoinRequestEntity> joinRequests;

  /// The current user's role in this community.
  final CommunityMemberEntity? currentMember;

  final bool isWorking; // true during async operations
  final String? error;

  const CommunityDetailLoaded({
    required this.community,
    this.groups = const [],
    this.members = const [],
    this.joinRequests = const [],
    this.currentMember,
    this.isWorking = false,
    this.error,
  });

  bool get isMember => currentMember != null;
  bool get isAdmin => currentMember?.isAdmin ?? false;
  bool get isSuperAdmin =>
      currentMember?.role == CommunityRole.superAdmin;

  /// The announcement group — always the first isAnnouncementOnly group.
  GroupEntity? get announcementGroup => groups
      .where((g) => g.isAnnouncementOnly)
      .cast<GroupEntity?>()
      .firstOrNull;

  /// Regular (non-announcement) groups.
  List<GroupEntity> get regularGroups =>
      groups.where((g) => !g.isAnnouncementOnly).toList();

  CommunityDetailLoaded copyWith({
    CommunityEntity? community,
    List<GroupEntity>? groups,
    List<CommunityMemberEntity>? members,
    List<JoinRequestEntity>? joinRequests,
    Object? currentMember = _sentinel,
    bool? isWorking,
    Object? error = _sentinel,
  }) {
    return CommunityDetailLoaded(
      community: community ?? this.community,
      groups: groups ?? this.groups,
      members: members ?? this.members,
      joinRequests: joinRequests ?? this.joinRequests,
      currentMember: currentMember == _sentinel
          ? this.currentMember
          : currentMember as CommunityMemberEntity?,
      isWorking: isWorking ?? this.isWorking,
      error: error == _sentinel ? this.error : error as String?,
    );
  }

  @override
  List<Object?> get props => [
        community,
        groups,
        members,
        joinRequests,
        currentMember,
        isWorking,
        error,
      ];
}

class CommunityDetailError extends CommunityDetailState {
  final String message;
  const CommunityDetailError(this.message);
  @override
  List<Object?> get props => [message];
}

const Object _sentinel = Object();

