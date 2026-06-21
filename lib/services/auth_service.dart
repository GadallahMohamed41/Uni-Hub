import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current logged-in user
  // بيرجع اليوزر الحالي اللي داخل التطبيق دلوقتي
  User? get currentUser => _auth.currentUser;

  // Listen to authentication state changes
  // بيسمع أي تغيير في حالة اللوجين (دخول/خروج/حذف)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign Up
  // بيسجل يوزر جديد وبيحفظ بياناته في Firestore ويبعت تأكيد إيميل
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String name,
    String? studentId,
    String? department,
    String? universityKey,
    String? departmentKey,
    String? levelKey,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user!;
      try {
        await user.updateDisplayName(name);
      } catch (_) {}

      final userModel = UserModel(
        uid: user.uid,
        name: name,
        email: email,
        studentId: studentId,
        department: department,
        bio: 'Student',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        universityKey: universityKey,
        departmentKey: departmentKey,
        levelKey: levelKey,
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(userModel.toFirestore());

      if (user.emailVerified == false) {
        try {
          await _sendCustomEmailVerification(email);
        } catch (_) {}
      }

      return userModel;

    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code);
    }
  }

  // Sign In
  // بيسجل دخول بالإيميل والباسورد، وبيحدث آخر وقت دخول
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user!;

      if (user.emailVerified == false) {
        try {
          await _sendCustomEmailVerification(email);
        } catch (_) {}
      }

      // Update last login time
      await _firestore
          .collection('users')
          .doc(user.uid)
          .update({'lastLogin': Timestamp.now()});

      final data = await getUserData(user.uid)
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (data != null) return data;

      final minimal = UserModel(
        uid: user.uid,
        name: (user.displayName ?? '').trim().isEmpty ? 'Student' : user.displayName!.trim(),
        email: user.email ?? email,
        bio: 'Student',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(minimal.toFirestore(), SetOptions(merge: true));
      return minimal;

    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e.code);
    }
  }

  // بيرسل تاني إيميل التأكيد لو لسه متأكدش
  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (user.emailVerified == true) return;
    await _sendCustomEmailVerification(user.email ?? '');
  }

  // بيعمل ريفرش لليوزر ويتأكد هل الإيميل اتأكد ولا لأ
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }


  // Sign Out
  // بيعمل تسجيل خروج من Firebase
  Future<void> signOut() async {
    await _auth.signOut();
  }


  // Get User Data
  // بيجيب بيانات اليوزر من Firestore بالـ uid
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('GetUserData Error: $e');
      rethrow;
    }
  }

  // Update User Data
  // بيحدث بيانات اليوزر في Firestore
  Future<void> updateUserData(
      String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // Reset Password
  // بيبعت لينك إعادة تعيين الباسورد على الإيميل عبر الـ Cloud Function الخاصة بنا بتصميم HTML فاخر
  Future<void> resetPassword(String email) async {
    try {
      final url = Uri.parse('https://europe-west1-university-connect-52779.cloudfunctions.net/sendCustomResetPassword');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        String errorMessage = 'Failed to send reset email';
        try {
          final Map<String, dynamic> responseData = jsonDecode(response.body);
          errorMessage = responseData['error'] ?? errorMessage;
        } catch (_) {}
        
        if (errorMessage.contains('No account found')) {
          throw _mapAuthError('user-not-found');
        }
        throw errorMessage;
      }
    } catch (e) {
      if (e is FirebaseAuthException) {
        throw _mapAuthError(e.code);
      }
      if (e.toString().contains('No account found') || e.toString().contains('No user found')) {
        throw _mapAuthError('user-not-found');
      }
      rethrow;
    }
  }
  // Helper to send custom verification email via Cloud Function
  Future<void> _sendCustomEmailVerification(String email) async {
    try {
      final url = Uri.parse('https://europe-west1-university-connect-52779.cloudfunctions.net/sendCustomEmailVerification');
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('Custom Email Verification Error: $e');
    }
  }

  // Centralized Error Mapping
  // بيحوّل أكواد أخطاء Firebase لرسائل مفهومة للمستخدم
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
