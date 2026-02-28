import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? studentId;
  final String? department;
  final String? bio;
  final String? avatarUrl;
  final String role; // 'student' or 'admin'
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String? universityKey; // مفتاح الجامعة لاستخدامه في الجداول
  final String? departmentKey; // مفتاح القسم للجداول
  final String? levelKey; // مفتاح الفرقة للجداول

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.studentId,
    this.department,
    this.bio,
    this.avatarUrl,
    this.role = 'student',
    required this.createdAt,
    this.lastLogin,
    this.universityKey,
    this.departmentKey,
    this.levelKey,
  });

  // إنشاء من Firestore Document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final avatarUrl = (data['avatarUrl'] as String?)?.trim();
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      studentId: data['studentId'],
      department: data['department'],
      bio: data['bio'],
      avatarUrl: (avatarUrl == null || avatarUrl.isEmpty) ? null : avatarUrl,
      role: data['role'] ?? 'student',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      universityKey: data['universityKey'],
      departmentKey: data['departmentKey'],
      levelKey: data['levelKey'],
    );
  }

  // تحويل إلى Map للحفظ في Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'studentId': studentId,
      'department': department,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'universityKey': universityKey,
      'departmentKey': departmentKey,
      'levelKey': levelKey,
    };
  }

  // نسخة محدثة من المستخدم
  UserModel copyWith({
    String? name,
    String? email,
    String? studentId,
    String? department,
    String? bio,
    String? avatarUrl,
    String? role,
    DateTime? lastLogin,
    String? universityKey,
    String? departmentKey,
    String? levelKey,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      studentId: studentId ?? this.studentId,
      department: department ?? this.department,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      createdAt: createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      universityKey: universityKey ?? this.universityKey,
      departmentKey: departmentKey ?? this.departmentKey,
      levelKey: levelKey ?? this.levelKey,
    );
  }

  bool get isAdmin => role == 'admin';
}
