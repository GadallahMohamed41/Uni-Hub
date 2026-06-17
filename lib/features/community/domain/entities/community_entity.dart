import 'package:equatable/equatable.dart';

/// Role of a user within a Community.
enum CommunityRole { superAdmin, admin, member }

/// Core domain entity for a Community (parent of multiple groups).
/// Pure Dart — no Firebase imports.
///
/// NOTE: memberIds and groupIds are intentionally NOT stored here.
/// - Members are fetched via subcollection: communities/{id}/members
/// - Groups are fetched via Firestore query: where(communityId == id)
class CommunityEntity extends Equatable {
  final String id;
  final String name;
  final String description;
  final String? imageUrl;
  final String createdBy;

  /// The announcement channel group id (isAnnouncementOnly = true).
  final String announcementGroupId;

  /// UUID-based invite link token.
  final String inviteLink;

  /// If true, users can join directly. If false, a join request is required.
  final bool isPublic;

  final DateTime createdAt;

  const CommunityEntity({
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

  /// Returns true if [uid] is the original creator of this community.
  bool isCreator(String uid) => createdBy == uid;

  CommunityEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    String? createdBy,
    String? announcementGroupId,
    String? inviteLink,
    bool? isPublic,
    DateTime? createdAt,
  }) {
    return CommunityEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      announcementGroupId: announcementGroupId ?? this.announcementGroupId,
      inviteLink: inviteLink ?? this.inviteLink,
      isPublic: isPublic ?? this.isPublic,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        imageUrl,
        createdBy,
        announcementGroupId,
        inviteLink,
        isPublic,
        createdAt,
      ];
}
