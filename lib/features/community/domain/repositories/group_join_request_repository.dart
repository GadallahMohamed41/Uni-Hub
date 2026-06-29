<<<<<<< HEAD
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';
=======
import '../entities/group_join_request_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

abstract class GroupJoinRequestRepository {
  /// Submit a request to join a private group.
  Future<void> submitRequest({
    required String groupId,
    required String groupName,
    String? groupImageUrl,
    required String userId,
    required String userName,
    String? userAvatarUrl,
    required String inviteToken,
  });

  /// Listen to pending requests for a group in real-time (admin view).
  Stream<List<GroupJoinRequestEntity>> watchPendingRequests(String groupId);

  /// Approve a request, adding the user to group membership.
  Future<void> approveRequest({
    required String requestId,
    required String groupId,
    required String userId,
    required String userName,
    String? userAvatarUrl,
  });

  /// Reject/deny a join request.
  Future<void> rejectRequest({required String requestId});

  /// Get details of a single join request.
  Future<GroupJoinRequestEntity?> getRequest(String requestId);
}
