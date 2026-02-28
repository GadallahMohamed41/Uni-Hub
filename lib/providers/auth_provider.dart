import 'package:flutter/material.dart';
import 'dart:async';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/push_notifications_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _authStateSubscription;

  // Getters
  // بيرجع بيانات اليوزر اللي مخزّنينها محلياً
  UserModel? get currentUser => _currentUser;
  // بيدل هل فيه عملية شغالة (لودينج) ولا لأ
  bool get isLoading => _isLoading;
  // آخر خطأ حصل
  String? get error => _error;
  // هل فيه يوزر داخل حالياً
  bool get isAuthenticated => _authService.currentUser != null;
  // الـ uid الحالي
  String? get userId => _authService.currentUser?.uid;
  // حالة تأكيد الإيميل
  bool get isEmailVerified => _authService.currentUser?.emailVerified ?? false;

  // التحقق من حالة المصادقة عند بدء التطبيق
  // بيشيّك على حالة اللوجين ويحمّل بيانات اليوزر ويبدأ مستمع الحالة
  Future<void> checkAuthState() async {
    final user = _authService.currentUser;
    if (user != null) {
      _currentUser = await _authService.getUserData(user.uid);
      if (user.emailVerified) {
        await PushNotificationsService.instance.setUserId(user.uid);
      }
      notifyListeners();
    }
    // Initialize auth state listener for account deletion detection
    _initAuthStateListener();
  }

  // Initialize Firebase auth state listener to detect account deletion
  // بيشغّل مستمع على Firebase لو الحساب اتمسح أو اتعمل لوج آوت نحدّث الحالة
  void _initAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _authService.authStateChanges.listen((user) async {
      if (user == null && _currentUser != null) {
        // User account was deleted or signed out from Firebase
        await _handleAccountDeletion();
      } else if (user != null && _currentUser == null) {
        // New user signed in
        await checkAuthState();
      }
    });
  }

  // Handle account deletion by logging out the user
  // بينضّف حالة اليوزر محلياً لو الحساب اتمسح من Firebase
  Future<void> _handleAccountDeletion() async {
    await PushNotificationsService.instance.clearUser();
    _currentUser = null;
    _error = 'Account deleted or no longer exists';
    notifyListeners();
  }

  // تسجيل مستخدم جديد
  // بينادي خدمة التسجيل ويحفظ اليوزر في الحالة
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    String? studentId,
    String? department,
    String? universityKey,
    String? departmentKey,
    String? levelKey,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        name: name,
        studentId: studentId,
        department: department,
        universityKey: universityKey,
        departmentKey: departmentKey,
        levelKey: levelKey,
      );
      notifyListeners();
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // تسجيل الدخول
  // بيسجل دخول وبيجهّز الإشعارات لو الإيميل متأكد
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      );
      if (_authService.currentUser?.emailVerified == true) {
        Future.microtask(() => PushNotificationsService.instance.setUserId(_currentUser?.uid));
      }
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // بيرسل إيميل تأكيد تاني
  Future<void> resendEmailVerification() async {
    try {
      await _authService.resendEmailVerification();
    } catch (e) {
      _setError(e.toString());
    }
  }

  // بيعمل ريفرش لليوزر ويتأكد إن الإيميل اتأكد ويحدّث البيانات
  Future<bool> refreshEmailVerified() async {
    try {
      final ok = await _authService.reloadAndCheckEmailVerified();
      if (ok) {
        final userId = _authService.currentUser?.uid;
        if (userId != null) {
          _currentUser = await _authService.getUserData(userId);
          Future.microtask(() => PushNotificationsService.instance.setUserId(userId));
        }
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  // تسجيل الخروج
  // بيوقف الإشعارات وبيعمل SignOut ويفرّغ الحالة
  Future<void> signOut() async {
    await PushNotificationsService.instance.clearUser();
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // تنظيف الموارد عند التخلص من الـ Provider
  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // إعادة تعيين كلمة المرور
  // بيبعت لينك إعادة تعيين الباسورد
  Future<bool> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      await _authService.resetPassword(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // تحديث بيانات المستخدم محلياً
  // بيعدّل نسخة اليوزر المحلية وينبه الليسنرز
  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  // تحديث بيانات البروفايل في Firestore + محلياً
  // بيحدّث بيانات البروفايل في Firestore وبعدين يحدّثها محلياً
  Future<bool> updateProfile({
    required String name,
    String? bio,
    String? studentId,
  }) async {
    final user = _currentUser;
    if (user == null) {
      _setError('User not authenticated');
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final data = <String, dynamic>{
        'name': name,
        'bio': bio,
        'studentId': studentId,
      }..removeWhere((k, v) => v == null);

      await _authService.updateUserData(user.uid, data);

      _currentUser = user.copyWith(
        name: name,
        bio: bio,
        studentId: studentId,
      );
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // Helper methods
  // بيسيّت حالة اللودينج وينبه الليسنرز
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // بيسيّت رسالة الخطأ وينبه الليسنرز
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  // بيمسح الخطأ من غير ما ينبه حد
  void _clearError() {
    _error = null;
  }

  // بيمسح الخطأ وينبه الليسنرز
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
