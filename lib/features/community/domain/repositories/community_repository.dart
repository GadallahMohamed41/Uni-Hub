import '../entities/community_entity.dart';
import '../entities/community_member_entity.dart';
import '../entities/join_request_entity.dart';
import '../entities/group_entity.dart';

/// Abstract contract for all Community operations.
/// Implementations live in the data layer.
abstract class CommunityRepository {
  // ── Community CRUD ──────────────────────────────────────────────────────────

  /// Creates a new community along with its announcement group.
  /// The creator is automatically added as [CommunityRole.superAdmin].
  Future<CommunityEntity> createCommunity({
    required String name,
    required String description,
    required String createdBy,
    required String creatorName,
    required String? creatorAvatarUrl,
    String? imageUrl,
    bool isPublic = true,
  });

  Future<void> updateCommunityInfo({
    required String communityId,
    String? name,
    String? description,
    String? imageUrl,
    bool? isPublic,
  });

  /// Deletes the community document and its subcollections.
  /// Groups are DETACHED (communityId set to null) — NOT deleted.
  Future<void> deleteCommunity({
    required String communityId,
    required String actorId,
  });

  Future<CommunityEntity?> getCommunity(String communityId);

  Future<CommunityEntity?> getCommunityByInviteLink(String inviteLink);

  // ── Real-time streams ───────────────────────────────────────────────────────

  /// Stream of communities where the user is a member.
  /// Listens to changes in communities where user has a member doc.
  Stream<List<CommunityEntity>> watchUserCommunities(String userId);

  /// Stream of groups belonging to this community.
  /// Fetched via: groups.where(communityId == communityId)
  Stream<List<GroupEntity>> watchCommunityGroups(String communityId);

  /// Stream of members subcollection for a community.
  Stream<List<CommunityMemberEntity>> watchCommunityMembers(String communityId);

  /// Stream of pending join requests (visible to admins only).
  Stream<List<JoinRequestEntity>> watchJoinRequests(String communityId);

  // ── Join / Leave ────────────────────────────────────────────────────────────

  /// Public community: adds user to members + announcement group.
  Future<void> joinCommunity({
    required String communityId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  });

  /// Private community: creates a pending join request.
  Future<void> requestToJoinCommunity({
    required String communityId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
  });

  /// Admin approves a join request:
  /// 1. Updates request status to approved
  /// 2. Adds user to members subcollection
  /// 3. Adds user to announcement group
  Future<void> approveJoinRequest({
    required String communityId,
    required String requestId,
    required String userId,
    required String userName,
    required String? userAvatarUrl,
    required String actorId,
  });

  Future<void> denyJoinRequest({
    required String communityId,
    required String requestId,
    required String actorId,
  });

  Future<void> leaveCommunity({
    required String communityId,
    required String userId,
  });

  // ── Member Management ───────────────────────────────────────────────────────

  Future<void> removeCommunityMember({
    required String communityId,
    required String targetUserId,
    required String actorId,
  });

  Future<void> promoteToCommunityAdmin({
    required String communityId,
    required String targetUserId,
    required String actorId,
  });

  Future<void> demoteFromCommunityAdmin({
    required String communityId,
    required String targetUserId,
    required String actorId,
  });

  Future<CommunityMemberEntity?> getMember({
    required String communityId,
    required String userId,
  });

  // ── Group Management ────────────────────────────────────────────────────────

  /// Creates a new group and links it to this community.
  Future<GroupEntity> createGroupInCommunity({
    required String communityId,
    required String name,
    required String description,
    required String ownerId,
    required String ownerName,
    required String? ownerAvatarUrl,
    String? imageUrl,
    bool isAnnouncementOnly = false,
  });

  /// Links an existing standalone group to a community.
  Future<void> addGroupToCommunity({
    required String communityId,
    required String groupId,
  });

  /// Detaches a group from a community by setting communityId = null.
  Future<void> removeGroupFromCommunity({
    required String groupId,
  });

  // ── Invite Link ─────────────────────────────────────────────────────────────

  Future<String> regenerateCommunityInviteLink(String communityId);
}
