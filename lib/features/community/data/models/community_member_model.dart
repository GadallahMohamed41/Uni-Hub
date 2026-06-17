import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_member_entity.dart';

/// Firestore model for communities/{communityId}/members/{userId}.
class CommunityMemberModel {
  final String userId;
  final CommunityRole role;
  final DateTime joinedAt;

  const CommunityMemberModel({
    required this.userId,
    required this.role,
    required this.joinedAt,
  });

  factory CommunityMemberModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityMemberModel(
      userId: doc.id,
      role: _roleFromString(d['role'] as String?),
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'role': _roleToString(role),
        'joinedAt': Timestamp.fromDate(joinedAt),
      };

  CommunityMemberEntity toEntity() => CommunityMemberEntity(
        userId: userId,
        role: role,
        joinedAt: joinedAt,
      );

  static CommunityRole _roleFromString(String? v) {
    switch (v) {
      case 'superAdmin':
        return CommunityRole.superAdmin;
      case 'admin':
        return CommunityRole.admin;
      default:
        return CommunityRole.member;
    }
  }

  static String _roleToString(CommunityRole r) {
    switch (r) {
      case CommunityRole.superAdmin:
        return 'superAdmin';
      case CommunityRole.admin:
        return 'admin';
      case CommunityRole.member:
        return 'member';
    }
  }
}
