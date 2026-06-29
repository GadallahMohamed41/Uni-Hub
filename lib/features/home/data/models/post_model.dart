import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String userBio;
  final String? userAvatarUrl;
  final String text;
  final String? imageUrl;
  final List<String> imageUrls;
  final String? videoUrl;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;
  final List<String> likedBy; // قائمة IDs المستخدمين الذين أعجبوا بالمنشور
  final List<String> laughedBy; // قائمة IDs المستخدمين الذين ضحكوا على المنشور
  final List<String> supportedBy; // قائمة IDs المستخدمين الذين دعموا المنشور
  final int laughedCount;
  final int supportedCount;
  final String? repostOf;
  final String? originalUserName;
  final String? originalText;
  final String? originalImageUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final String privacyLevel; // 'everyone', 'friends', 'only_me'
  final String? feeling; // optional feeling string/emoji

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userBio,
    this.userAvatarUrl,
    required this.text,
    this.imageUrl,
    this.imageUrls = const [],
    this.videoUrl,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.likedBy = const [],
    this.laughedBy = const [],
    this.supportedBy = const [],
    this.laughedCount = 0,
    this.supportedCount = 0,
    this.repostOf,
    this.originalUserName,
    this.originalText,
    this.originalImageUrl,
    this.status = 'pending',
    this.privacyLevel = 'everyone',
    this.feeling,
  });

  // إنشاء من Firestore Document
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userAvatarUrl = (data['userAvatarUrl'] as String?)?.trim();
    final singleImageUrl = (data['imageUrl'] as String?)?.trim();
    final listImageUrls = (data['imageUrls'] is List)
        ? List<String>.from(data['imageUrls'] as List)
        : const <String>[];
    final filteredImageUrls = listImageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final normalizedImageUrls = filteredImageUrls.isNotEmpty
        ? filteredImageUrls
        : (singleImageUrl != null && singleImageUrl.isNotEmpty ? [singleImageUrl] : const <String>[]);
    final originalImageUrl = (data['originalImageUrl'] as String?)?.trim();
    final videoUrl = (data['videoUrl'] as String?)?.trim();
    return PostModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userBio: data['userBio'] ?? '',
      userAvatarUrl:
          (userAvatarUrl == null || userAvatarUrl.isEmpty) ? null : userAvatarUrl,
      text: data['text'] ?? '',
      imageUrl: (singleImageUrl == null || singleImageUrl.isEmpty) ? null : singleImageUrl,
      imageUrls: normalizedImageUrls,
      videoUrl: (videoUrl == null || videoUrl.isEmpty) ? null : videoUrl,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      laughedBy: List<String>.from(data['laughedBy'] ?? []),
      supportedBy: List<String>.from(data['supportedBy'] ?? []),
      laughedCount: data['laughedCount'] ?? 0,
      supportedCount: data['supportedCount'] ?? 0,
      repostOf: data['repostOf'],
      originalUserName: data['originalUserName'],
      originalText: data['originalText'],
      originalImageUrl:
          (originalImageUrl == null || originalImageUrl.isEmpty) ? null : originalImageUrl,
      status: data['status'] ?? 'pending',
      privacyLevel: data['privacyLevel'] ?? 'everyone',
      feeling: data['feeling'],
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userBio': userBio,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
      'laughedBy': laughedBy,
      'supportedBy': supportedBy,
      'laughedCount': laughedCount,
      'supportedCount': supportedCount,
      'repostOf': repostOf,
      'originalUserName': originalUserName,
      'originalText': originalText,
      'originalImageUrl': originalImageUrl,
      'status': status,
      'privacyLevel': privacyLevel,
      'feeling': feeling,
    };
  }

  // حساب الوقت المنسق
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w';
    } else {
      return '${(difference.inDays / 30).floor()}mo';
    }
  }

  // التحقق إذا المستخدم أعجب بالمنشور
  bool isLikedByUser(String userId) {
    return likedBy.contains(userId);
  }

  // التحقق إذا المستخدم ضحك على المنشور
  bool isLaughedByUser(String userId) {
    return laughedBy.contains(userId);
  }

  // التحقق إذا المستخدم دعّم المنشور
  bool isSupportedByUser(String userId) {
    return supportedBy.contains(userId);
  }

  // الحصول على إجمالي التفاعلات
  int get totalReactions => likesCount + laughedCount + supportedCount;

  // نسخة محدثة
  PostModel copyWith({
    String? text,
    String? imageUrl,
    List<String>? imageUrls,
    String? videoUrl,
    int? likesCount,
    int? commentsCount,
    List<String>? likedBy,
    List<String>? laughedBy,
    List<String>? supportedBy,
    int? laughedCount,
    int? supportedCount,
    String? repostOf,
    String? originalUserName,
    String? originalText,
    String? originalImageUrl,
    String? status,
    String? privacyLevel,
    String? feeling,
  }) {
    return PostModel(
      id: id,
      userId: userId,
      userName: userName,
      userBio: userBio,
      userAvatarUrl: userAvatarUrl,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      createdAt: createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      likedBy: likedBy ?? this.likedBy,
      laughedBy: laughedBy ?? this.laughedBy,
      supportedBy: supportedBy ?? this.supportedBy,
      laughedCount: laughedCount ?? this.laughedCount,
      supportedCount: supportedCount ?? this.supportedCount,
      repostOf: repostOf ?? this.repostOf,
      originalUserName: originalUserName ?? this.originalUserName,
      originalText: originalText ?? this.originalText,
      originalImageUrl: originalImageUrl ?? this.originalImageUrl,
      status: status ?? this.status,
      privacyLevel: privacyLevel ?? this.privacyLevel,
      feeling: feeling ?? this.feeling,
    );
  }

  factory PostModel.fromMap(Map<String, dynamic> data, String id) {
    final userAvatarUrl = (data['userAvatarUrl'] as String?)?.trim();
    final singleImageUrl = (data['imageUrl'] as String?)?.trim();
    final listImageUrls = (data['imageUrls'] is List)
        ? List<String>.from(data['imageUrls'] as List)
        : const <String>[];
    final filteredImageUrls = listImageUrls.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final normalizedImageUrls = filteredImageUrls.isNotEmpty
        ? filteredImageUrls
        : (singleImageUrl != null && singleImageUrl.isNotEmpty ? [singleImageUrl] : const <String>[]);
    final originalImageUrl = (data['originalImageUrl'] as String?)?.trim();
    final videoUrl = (data['videoUrl'] as String?)?.trim();
    
    DateTime createdAtVal;
    if (data['createdAt'] is Timestamp) {
      createdAtVal = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAtVal = DateTime.parse(data['createdAt'] as String);
    } else {
      createdAtVal = DateTime.now();
    }

    return PostModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userBio: data['userBio'] ?? '',
      userAvatarUrl:
          (userAvatarUrl == null || userAvatarUrl.isEmpty) ? null : userAvatarUrl,
      text: data['text'] ?? '',
      imageUrl: (singleImageUrl == null || singleImageUrl.isEmpty) ? null : singleImageUrl,
      imageUrls: normalizedImageUrls,
      videoUrl: (videoUrl == null || videoUrl.isEmpty) ? null : videoUrl,
      createdAt: createdAtVal,
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      laughedBy: List<String>.from(data['laughedBy'] ?? []),
      supportedBy: List<String>.from(data['supportedBy'] ?? []),
      laughedCount: data['laughedCount'] ?? 0,
      supportedCount: data['supportedCount'] ?? 0,
      repostOf: data['repostOf'],
      originalUserName: data['originalUserName'],
      originalText: data['originalText'],
      originalImageUrl:
          (originalImageUrl == null || originalImageUrl.isEmpty) ? null : originalImageUrl,
      status: data['status'] ?? 'pending',
      privacyLevel: data['privacyLevel'] ?? 'everyone',
      feeling: data['feeling'],
    );
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userBio': userBio,
      'userAvatarUrl': userAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'videoUrl': videoUrl,
      'createdAt': createdAt.toIso8601String(),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'likedBy': likedBy,
      'laughedBy': laughedBy,
      'supportedBy': supportedBy,
      'laughedCount': laughedCount,
      'supportedCount': supportedCount,
      'repostOf': repostOf,
      'originalUserName': originalUserName,
      'originalText': originalText,
      'originalImageUrl': originalImageUrl,
      'status': status,
      'privacyLevel': privacyLevel,
      'feeling': feeling,
    };
  }
}
