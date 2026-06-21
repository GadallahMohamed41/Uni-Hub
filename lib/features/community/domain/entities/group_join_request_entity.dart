import 'package:equatable/equatable.dart';

enum GroupJoinRequestStatus { pending, approved, rejected }

/// Represents a user's request to join a private group.
class GroupJoinRequestEntity extends Equatable {
  final String requestId;
  final String groupId;
  final String groupName;
  final String? groupImageUrl;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime requestedAt;
  final GroupJoinRequestStatus status;

  const GroupJoinRequestEntity({
    required this.requestId,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.requestedAt,
    this.status = GroupJoinRequestStatus.pending,
  });

  bool get isPending => status == GroupJoinRequestStatus.pending;
  bool get isApproved => status == GroupJoinRequestStatus.approved;
  bool get isRejected => status == GroupJoinRequestStatus.rejected;

  @override
  List<Object?> get props => [
        requestId,
        groupId,
        groupName,
        groupImageUrl,
        userId,
        userName,
        userAvatarUrl,
        requestedAt,
        status,
      ];
}
