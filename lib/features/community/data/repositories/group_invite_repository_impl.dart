import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/group_invite_entity.dart';
import '../../domain/repositories/group_invite_repository.dart';
import '../models/group_invite_model.dart';

class GroupInviteRepositoryImpl implements GroupInviteRepository {
  final FirebaseFirestore _db;
  final _uuid = const Uuid();

  GroupInviteRepositoryImpl({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('group_invites');

  @override
  Future<GroupInviteEntity> createInvite({
    required String groupId,
    required String creatorId,
    DateTime? expiresAt,
    int? maxUses,
    required bool requiresApproval,
  }) async {
    final token = _uuid.v4();
    final model = GroupInviteModel(
      inviteToken: token,
      groupId: groupId,
      creatorId: creatorId,
      createdAt: DateTime.now(),
      expiresAt: expiresAt,
      maxUses: maxUses,
      useCount: 0,
      requiresApproval: requiresApproval,
      isRevoked: false,
    );

    await _invites.doc(token).set(model.toMap());
    return model.toEntity();
  }

  @override
  Future<GroupInviteEntity?> getInvite(String inviteToken) async {
    final doc = await _invites.doc(inviteToken).get();
    if (!doc.exists) return null;
    return GroupInviteModel.fromFirestore(doc).toEntity();
  }

  @override
  Future<void> revokeInvite(String inviteToken) async {
    await _invites.doc(inviteToken).update({'isRevoked': true});
  }

  @override
  Future<void> incrementUseCount(String inviteToken) async {
    await _invites.doc(inviteToken).update({
      'useCount': FieldValue.increment(1),
    });
  }
}
