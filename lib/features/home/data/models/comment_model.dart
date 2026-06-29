import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userAvatarUrl;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDeleted;
  final String? parentCommentId;
  final int repliesCount;
  final List<String> likedBy;
  final int likesCount;
  final List<String> mentionedUserIds;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userAvatarUrl,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
    this.parentCommentId,
    this.repliesCount = 0,
    this.likedBy = const [],
    this.likesCount = 0,
    this.mentionedUserIds = const [],
  });

  // إنشاء من Firestore Document
  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userAvatarUrl = (data['userAvatarUrl'] as String?)?.trim();
    return CommentModel(
      id: doc.id,
      postId: data['postId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatarUrl:
          (userAvatarUrl == null || userAvatarUrl.isEmpty) ? null : userAvatarUrl,
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isDeleted: (data['isDeleted'] as bool?) ?? false,
      parentCommentId: data['parentCommentId'],
      repliesCount: data['repliesCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      likesCount: data['likesCount'] ?? 0,
      mentionedUserIds: List<String>.from(data['mentionedUserIds'] ?? []),
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'postId': postId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      'isDeleted': isDeleted,
      'parentCommentId': parentCommentId,
      'repliesCount': repliesCount,
      'likedBy': likedBy,
      'likesCount': likesCount,
      'mentionedUserIds': mentionedUserIds,
    };
  }

  // حساب الوقت المنسق
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}د';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}س';
    } else {
      return '${difference.inDays}ي';
    }
  }

  bool get isEdited {
    if (updatedAt == null) return false;
    return updatedAt!.isAfter(createdAt);
  }
}
