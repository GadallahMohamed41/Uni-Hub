import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? studentId;
  final String? department;
  final String? bio;
  final String? avatarUrl;
  final String? cvUrl;
  final String? certificateUrl;
  final String? coverUrl;
  final String role; // 'student' or 'admin'
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? universityKey;
  final String? departmentKey;
  final String? levelKey;

  final String? githubLink;
  final String? linkedinLink;
  final String? facebookLink;
  final String? instagramLink;
  final String? phoneNumber;
  final bool isBlocked;
  final DateTime? blockedUntil;
  final DateTime? blockedAt;

  // ═══════════════════════════════════════════════════════════════════════════
  // Follow System (Flow) Fields
  // ═══════════════════════════════════════════════════════════════════════════
  final int followersCount; // عدد الأشخاص اللي بيتبعوني
  final int followingCount; // عدد الأشخاص اللي أنا بتبعهم
  final int connectionsCount; // عدد الاتصالات (الأصدقاء)

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.studentId,
    this.department,
    this.bio,
    this.avatarUrl,
    this.cvUrl,
    this.certificateUrl,
    this.coverUrl,
    this.role = 'student',
    required this.createdAt,
    this.lastLogin,
    this.universityKey,
    this.departmentKey,
    this.levelKey,
    this.githubLink,
    this.linkedinLink,
    this.isBlocked = false,
    this.blockedUntil,
    this.blockedAt,
    this.facebookLink,
    this.instagramLink,
    this.phoneNumber,
    this.followersCount = 0,
    this.followingCount = 0,
    this.connectionsCount = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final avatarUrl = (data['avatarUrl'] as String?)?.trim();
    final cvUrl = (data['cvUrl'] as String?)?.trim();
    final certificateUrl = (data['certificateUrl'] as String?)?.trim();
    final coverUrl = (data['coverUrl'] as String?)?.trim();

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      studentId: data['studentId'],
      department: data['department'],
      bio: data['bio'],
      avatarUrl: (avatarUrl == null || avatarUrl.isEmpty) ? null : avatarUrl,
      cvUrl: (cvUrl == null || cvUrl.isEmpty) ? null : cvUrl,
      certificateUrl: (certificateUrl == null || certificateUrl.isEmpty)
          ? null
          : certificateUrl,
      coverUrl: (coverUrl == null || coverUrl.isEmpty) ? null : coverUrl,
      role: data['role'] ?? 'student',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      universityKey: data['universityKey'],
      departmentKey: data['departmentKey'],
      levelKey: data['levelKey'],
      githubLink: data['githubLink'],
      linkedinLink: data['linkedinLink'],
      isBlocked: data['isBlocked'] ?? false,
      blockedUntil: (data['blockedUntil'] as Timestamp?)?.toDate(),
      blockedAt: (data['blockedAt'] as Timestamp?)?.toDate(),
      facebookLink: data['facebookLink'],
      instagramLink: data['instagramLink'],
      phoneNumber: data['phoneNumber'],
      followersCount:
          data['followersCount'] is int ? data['followersCount'] as int : 0,
      followingCount:
          data['followingCount'] is int ? data['followingCount'] as int : 0,
      connectionsCount:
          data['connectionsCount'] is int ? data['connectionsCount'] as int : 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'studentId': studentId,
      'department': department,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'cvUrl': cvUrl,
      'certificateUrl': certificateUrl,
      'coverUrl': coverUrl,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'universityKey': universityKey,
      'departmentKey': departmentKey,
      'levelKey': levelKey,
      'githubLink': githubLink,
      'linkedinLink': linkedinLink,
      'isBlocked': isBlocked,
      'blockedUntil':
          blockedUntil != null ? Timestamp.fromDate(blockedUntil!) : null,
      'blockedAt': blockedAt != null ? Timestamp.fromDate(blockedAt!) : null,
      'facebookLink': facebookLink,
      'instagramLink': instagramLink,
      'phoneNumber': phoneNumber,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'connectionsCount': connectionsCount,
    };
  }

  UserModel copyWith({
    String? name,
    String? email,
    String? studentId,
    String? department,
    String? bio,
    String? avatarUrl,
    String? cvUrl,
    String? certificateUrl,
    String? coverUrl,
    String? role,
    DateTime? lastLogin,
    String? universityKey,
    String? departmentKey,
    String? levelKey,
    String? githubLink,
    String? linkedinLink,
    bool? isBlocked,
    DateTime? blockedUntil,
    DateTime? blockedAt,
    String? facebookLink,
    String? instagramLink,
    String? phoneNumber,
    int? followersCount,
    int? followingCount,
    int? connectionsCount,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      cvUrl: cvUrl ?? this.cvUrl,
      certificateUrl: certificateUrl ?? this.certificateUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      universityKey: universityKey ?? this.universityKey,
      departmentKey: departmentKey ?? this.departmentKey,
      levelKey: levelKey ?? this.levelKey,
      githubLink: githubLink ?? this.githubLink,
      linkedinLink: linkedinLink ?? this.linkedinLink,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedUntil: blockedUntil ?? this.blockedUntil,
      blockedAt: blockedAt ?? this.blockedAt,
      facebookLink: facebookLink ?? this.facebookLink,
      instagramLink: instagramLink ?? this.instagramLink,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      connectionsCount: connectionsCount ?? this.connectionsCount,
    );
  }

  bool get isAdmin => role == 'admin';
}
