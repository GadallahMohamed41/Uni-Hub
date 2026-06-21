import 'package:equatable/equatable.dart';

enum JoinRequestStatus { pending, approved, denied }

/// Represents a single entry in communities/{communityId}/joinRequests subcollection.
class JoinRequestEntity extends Equatable {
  final String id;
  final String communityId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime requestedAt;
  final JoinRequestStatus status;

  const JoinRequestEntity({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
  });

  bool get isPending => status == JoinRequestStatus.pending;

  @override
  List<Object?> get props => [id, communityId, userId, status, requestedAt];
}
