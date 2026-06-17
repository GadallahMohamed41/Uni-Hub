import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/push_notifications_service.dart';
import '../services/deep_link_service.dart';
import 'posts_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _authStateSubscription;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _authService.currentUser != null;
  String? get userId => _authService.currentUser?.uid;
  bool get isEmailVerified => _authService.currentUser?.emailVerified ?? false;

  Future<void> checkAuthState() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        // 1. Try to get cached data first (instant startup)
        try {
          final cachedDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(const GetOptions(source: Source.cache));
          if (cachedDoc.exists && cachedDoc.data() != null) {
            _currentUser = UserModel.fromFirestore(cachedDoc);
            notifyListeners();
            // Defer notification setup
            unawaited(_initNotificationsAndListeners(user.uid));
          }
        } catch (e) {
          debugPrint('[AuthProvider] Cache load failed: $e');
        }

        // 2. Fetch fresh data from server in the background (or foreground if cache was empty)
        final fetchFuture = _authService.getUserData(user.uid);
        
        if (_currentUser == null) {
          // If cache was empty, we wait for the server data with a shorter timeout
          _currentUser = await fetchFuture.timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint('[AuthProvider] Server fetch timed out');
            return null;
          });
          notifyListeners();
          if (_currentUser != null) {
            unawaited(_initNotificationsAndListeners(user.uid));
          }
        } else {
          // If we already had cached data, update it silently/asynchronously in the background
          unawaited(() async {
            try {
              final freshUser = await fetchFuture;
              if (freshUser != null) {
                _currentUser = freshUser;
                notifyListeners();
              }
            } catch (e) {
              debugPrint('[AuthProvider] Background server refresh failed: $e');
            }
          }());
        }
      }
    } catch (e, stack) {
      debugPrint('[AuthProvider] Error in checkAuthState: $e\n$stack');
    } finally {
      _initAuthStateListener();
    }
  }

  Future<void> _initNotificationsAndListeners(String uid) async {
    try {
      await PushNotificationsService.instance.setUserId(uid);
      if (_currentUser != null && _currentUser!.role == 'student') {
        final uKey = _currentUser!.universityKey;
        final dKey = _currentUser!.departmentKey;
        final lKey = _currentUser!.levelKey;
        if (uKey != null && dKey != null && lKey != null &&
            uKey.isNotEmpty && dKey.isNotEmpty && lKey.isNotEmpty) {
          await PushNotificationsService.instance.subscribeToAcademicTopic(
            universityKey: uKey,
            departmentKey: dKey,
            levelKey: lKey,
          );
        }
      }
      DeepLinkService.instance.checkPendingLink();
    } catch (e, stack) {
      debugPrint('[AuthInit] Error in background listeners initialization: $e\n$stack');
    }
  }

  void _initAuthStateListener() {
    _authStateSubscription?.cancel();
    _authStateSubscription = _authService.authStateChanges.listen((user) async {
      if (user == null && _currentUser != null) {
        await _handleAccountDeletion();
      } else if (user != null && _currentUser == null) {
        await checkAuthState();
      }
    });
  }

  Future<void> _handleAccountDeletion() async {
    await PushNotificationsService.instance.clearUser();
    _currentUser = null;
    _error = 'Account deleted or no longer exists';
    notifyListeners();
  }

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
      // السماح بالإشعارات عند تسجيل الدخول
      if (_currentUser != null) {
        Future.microtask(() {
          PushNotificationsService.instance.setUserId(_currentUser?.uid);
          if (_currentUser!.role == 'student') {
            final uKey = _currentUser!.universityKey;
            final dKey = _currentUser!.departmentKey;
            final lKey = _currentUser!.levelKey;
            if (uKey != null && dKey != null && lKey != null &&
                uKey.isNotEmpty && dKey.isNotEmpty && lKey.isNotEmpty) {
              PushNotificationsService.instance.subscribeToAcademicTopic(
                universityKey: uKey,
                departmentKey: dKey,
                levelKey: lKey,
              );
            }
          }
        });
      }
      _setLoading(false);
      return _currentUser != null;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> resendEmailVerification() async {
    try {
      await _authService.resendEmailVerification();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> refreshEmailVerified() async {
    try {
      final ok = await _authService.reloadAndCheckEmailVerified();
      if (ok) {
        final userId = _authService.currentUser?.uid;
        if (userId != null) {
          _currentUser = await _authService.getUserData(userId);
          Future.microtask(() {
            PushNotificationsService.instance.setUserId(userId);
            if (_currentUser != null && _currentUser!.role == 'student') {
              final uKey = _currentUser!.universityKey;
              final dKey = _currentUser!.departmentKey;
              final lKey = _currentUser!.levelKey;
              if (uKey != null && dKey != null && lKey != null &&
                  uKey.isNotEmpty && dKey.isNotEmpty && lKey.isNotEmpty) {
                PushNotificationsService.instance.subscribeToAcademicTopic(
                  universityKey: uKey,
                  departmentKey: dKey,
                  levelKey: lKey,
                );
              }
            }
          });
        }
      }
      notifyListeners();
      return ok;
    } catch (e) {
      _setError(e.toString());
      return false;
    }
  }

  Future<void> signOut([BuildContext? context]) async {
    _authStateSubscription?.cancel();
    _authStateSubscription = null;

    await PushNotificationsService.instance.clearUser();

    if (context != null && context.mounted) {
      try {
        Provider.of<PostsProvider>(context, listen: false).clearState();
      } catch (e) {
        debugPrint('[SignOut] Non-fatal error clearing PostsProvider: $e');
      }
    }

    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

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

  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<bool> updateProfile({
    required String name,
    String? bio,
    String? studentId,
    String? githubLink,
    String? linkedinLink,
    String? facebookLink,
    String? instagramLink,
    String? phoneNumber,
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
        'githubLink': githubLink,
        'linkedinLink': linkedinLink,
        'facebookLink': facebookLink,
        'instagramLink': instagramLink,
        'phoneNumber': phoneNumber,
      }..removeWhere((k, v) => v == null);

      await _authService.updateUserData(user.uid, data);

      _currentUser = user.copyWith(
        name: name,
        bio: bio,
        studentId: studentId,
        githubLink: githubLink ?? '',
        linkedinLink: linkedinLink ?? '',
        facebookLink: facebookLink ?? '',
        instagramLink: instagramLink ?? '',
        phoneNumber: phoneNumber ?? '',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // Follow / Unfollow System (Flow)
  // ═══════════════════════════════════════════════════════════════════════════

  /// متابعة مستخدم (Follow)
  Future<bool> followUser(String targetUserId) async {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) return false;
    if (currentUserId == targetUserId) return false;

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final followDocRef = FirebaseFirestore.instance
          .collection('followers')
          .doc(followDocId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.set(followDocRef, {
          'followerId': currentUserId,
          'followingId': targetUserId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(
          FirebaseFirestore.instance.collection('users').doc(targetUserId),
          {'followersCount': FieldValue.increment(1)},
        );
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// إلغاء متابعة مستخدم (Unfollow)
  Future<bool> unfollowUser(String targetUserId) async {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) return false;
    if (currentUserId == targetUserId) return false;

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final followDocRef = FirebaseFirestore.instance
          .collection('followers')
          .doc(followDocId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        transaction.delete(followDocRef);

        transaction.update(
          FirebaseFirestore.instance.collection('users').doc(targetUserId),
          {'followersCount': FieldValue.increment(-1)},
        );
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// جلب عدد المتابعين لمستخدم معين
  Future<int> getFollowersCount(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return (doc.data()?['followersCount'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// جلب عدد المستخدمين الذي يتابعهم هذا المستخدم
  Future<int> getFollowingCount(String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('followers')
          .where('followerId', isEqualTo: userId)
          .get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  /// التحقق إذا كان المستخدم الحالي يتابع شخص معين
  Future<bool> isFollowing(String targetUserId) async {
    final currentUserId = _currentUser?.uid;
    if (currentUserId == null) return false;
    if (currentUserId == targetUserId) return false;

    try {
      final followDocId = '${currentUserId}_$targetUserId';
      final doc = await FirebaseFirestore.instance
          .collection('followers')
          .doc(followDocId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}