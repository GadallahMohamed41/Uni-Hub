import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/join_request_entity.dart';

/// Firestore model for communities/{communityId}/joinRequests/{requestId}.
class JoinRequestModel {
  final String id;
  final String communityId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final DateTime requestedAt;
  final JoinRequestStatus status;

  const JoinRequestModel({
    required this.id,
    required this.communityId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.requestedAt,
    this.status = JoinRequestStatus.pending,
  });

  factory JoinRequestModel.fromFirestore(
      DocumentSnapshot doc, String communityId) {
    final d = doc.data() as Map<String, dynamic>;
    return JoinRequestModel(
      id: doc.id,
      communityId: communityId,
      userId: (d['userId'] as String?) ?? '',
      userName: (d['userName'] as String?) ?? '',
      userAvatarUrl: d['userAvatarUrl'] as String?,
      requestedAt: (d['requestedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _statusFromString(d['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'userAvatarUrl': userAvatarUrl,
        'requestedAt': Timestamp.fromDate(requestedAt),
        'status': _statusToString(status),
      };

  JoinRequestEntity toEntity() => JoinRequestEntity(
        id: id,
        communityId: communityId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
        requestedAt: requestedAt,
        status: status,
      );

  static JoinRequestStatus _statusFromString(String? v) {
    switch (v) {
      case 'approved':
        return JoinRequestStatus.approved;
      case 'denied':
        return JoinRequestStatus.denied;
      default:
        return JoinRequestStatus.pending;
    }
  }

  static String _statusToString(JoinRequestStatus s) {
    switch (s) {
      case JoinRequestStatus.approved:
        return 'approved';
      case JoinRequestStatus.denied:
        return 'denied';
      case JoinRequestStatus.pending:
        return 'pending';
    }
  }
}
