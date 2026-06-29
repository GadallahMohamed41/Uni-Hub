import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';

/// Firestore-aware model that maps to/from [CommunityEntity].
class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String createdBy;
  final String announcementGroupId;
  final String inviteLink;
  final bool isPublic;
  final DateTime createdAt;

  const CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    this.imageUrl,
    required this.createdBy,
    required this.announcementGroupId,
    required this.inviteLink,
    this.isPublic = true,
    required this.createdAt,
  });

  factory CommunityModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityModel(
      id: doc.id,
      name: (d['name'] as String?) ?? '',
      description: (d['description'] as String?) ?? '',
      imageUrl: (d['imageUrl'] as String?)?.trim(),
      createdBy: (d['createdBy'] as String?) ?? '',
      announcementGroupId: (d['announcementGroupId'] as String?) ?? '',
      inviteLink: (d['inviteLink'] as String?) ?? '',
      isPublic: (d['isPublic'] as bool?) ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'createdBy': createdBy,
        'announcementGroupId': announcementGroupId,
        'inviteLink': inviteLink,
        'isPublic': isPublic,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  CommunityEntity toEntity() => CommunityEntity(
        id: id,
        name: name,
        description: description,
        imageUrl: imageUrl,
        createdBy: createdBy,
        announcementGroupId: announcementGroupId,
        inviteLink: inviteLink,
        isPublic: isPublic,
        createdAt: createdAt,
      );
}
