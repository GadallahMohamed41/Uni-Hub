import 'package:equatable/equatable.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';

/// Represents a single member entry in the communities/{id}/members subcollection.
class CommunityMemberEntity extends Equatable {
  final String userId;
  final CommunityRole role;
  final DateTime joinedAt;

  const CommunityMemberEntity({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  bool get isSuperAdmin => role == CommunityRole.superAdmin;
  bool get isAdmin => role == CommunityRole.admin || role == CommunityRole.superAdmin;

  CommunityMemberEntity copyWith({
    String? userId,
    CommunityRole? role,
    DateTime? joinedAt,
  }) {
    return CommunityMemberEntity(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [userId, role, joinedAt];
}
