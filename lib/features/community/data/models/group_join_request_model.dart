import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group_join_request_entity.dart';

class GroupJoinRequestModel {
  final String requestId;
  final String groupId;
  final String groupName;
  final String? groupImageUrl;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime requestedAt;
  final GroupJoinRequestStatus status;

  const GroupJoinRequestModel({
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

  factory GroupJoinRequestModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupJoinRequestModel(
      requestId: doc.id,
      groupId: (d['groupId'] as String?) ?? '',
      groupName: (d['groupName'] as String?) ?? '',
      groupImageUrl: d['groupImageUrl'] as String?,
      userId: (d['userId'] as String?) ?? '',
      userName: (d['userName'] as String?) ?? '',
      userAvatarUrl: d['userAvatarUrl'] as String?,
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _statusFromString(d['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'groupName': groupName,
        'groupImageUrl': groupImageUrl,
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'status': _statusToString(status),
      };

  GroupJoinRequestEntity toEntity() => GroupJoinRequestEntity(
        requestId: requestId,
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImageUrl,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        requestedAt: requestedAt,
        status: status,
      );

  factory GroupJoinRequestModel.fromEntity(GroupJoinRequestEntity entity) =>
      GroupJoinRequestModel(
        requestId: entity.requestId,
        groupId: entity.groupId,
        groupName: entity.groupName,
        groupImageUrl: entity.groupImageUrl,
        userId: entity.userId,
        userName: entity.userName,
        userAvatarUrl: entity.userAvatarUrl,
        requestedAt: entity.requestedAt,
        status: entity.status,
      );

  static GroupJoinRequestStatus _statusFromString(String? val) {
    switch (val) {
      case 'approved':
        return GroupJoinRequestStatus.approved;
      case 'rejected':
        return GroupJoinRequestStatus.rejected;
      default:
        return GroupJoinRequestStatus.pending;
    }
  }

  static String _statusToString(GroupJoinRequestStatus s) {
    switch (s) {
      case GroupJoinRequestStatus.approved:
        return 'approved';
      case GroupJoinRequestStatus.rejected:
        return 'rejected';
      case GroupJoinRequestStatus.pending:
        return 'pending';
    }
  }
}
