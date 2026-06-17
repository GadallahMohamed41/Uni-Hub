import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/group_invite_entity.dart';

class GroupInviteModel {
  final String inviteToken;
  final String groupId;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxUses;
  final int useCount;
  final bool requiresApproval;
  final bool isRevoked;

  const GroupInviteModel({
    required this.inviteToken,
    required this.groupId,
    required this.creatorId,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    this.requiresApproval = false,
    this.isRevoked = false,
  });

  factory GroupInviteModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GroupInviteModel(
      inviteToken: doc.id,
      groupId: (d['groupId'] as String?) ?? '',
      creatorId: (d['creatorId'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
      maxUses: d['maxUses'] as int?,
      useCount: (d['useCount'] as int?) ?? 0,
      requiresApproval: (d['requiresApproval'] as bool?) ?? false,
      isRevoked: (d['isRevoked'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'groupId': groupId,
        'creatorId': creatorId,
        'createdAt': Timestamp.fromDate(createdAt),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'maxUses': maxUses,
        'useCount': useCount,
        'requiresApproval': requiresApproval,
        'isRevoked': isRevoked,
      };

  GroupInviteEntity toEntity() => GroupInviteEntity(
        inviteToken: inviteToken,
        groupId: groupId,
        creatorId: creatorId,
        createdAt: createdAt,
        expiresAt: expiresAt,
        maxUses: maxUses,
        useCount: useCount,
        requiresApproval: requiresApproval,
        isRevoked: isRevoked,
      );

  factory GroupInviteModel.fromEntity(GroupInviteEntity entity) =>
      GroupInviteModel(
        inviteToken: entity.inviteToken,
        groupId: entity.groupId,
        creatorId: entity.creatorId,
        createdAt: entity.createdAt,
        expiresAt: entity.expiresAt,
        maxUses: entity.maxUses,
        useCount: entity.useCount,
        requiresApproval: entity.requiresApproval,
        isRevoked: entity.isRevoked,
      );
}
