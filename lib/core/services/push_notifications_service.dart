import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project_test2/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:project_test2/features/home/presentation/screens/post_detail_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/lectures_section_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/notifications_screen.dart';
import 'package:project_test2/features/chat/presentation/screens/direct_message_screen.dart';
import 'package:project_test2/features/community/data/models/community_model.dart';
import 'package:project_test2/features/community/presentation/screens/community_detail_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_chat_screen.dart';
import 'package:project_test2/firebase_options.dart';

/// Normalizes JSON from FCM / local notification payloads (often [Map] but not typed).
Map<String, dynamic>? decodeNotificationPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  try {
    final raw = jsonDecode(payload);
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    debugPrint('[NotifNav] Payload JSON was not an object');
    return null;
  } catch (e) {
    debugPrint('[NotifNav] Invalid notification payload JSON: $e');
    return null;
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  final actionId = response.actionId;
  final payload = response.payload;

  if (payload == null || actionId == null) return;

  try {
    final data = decodeNotificationPayload(payload);
    if (data == null) return;

    // Connection Request Background Actions
    if (actionId == 'accept_connection' || actionId == 'decline_connection') {
      final fromUserId = data['fromUserId']?.toString().trim();
      final notificationId = data['notificationId']?.toString().trim() ??
          data['id']?.toString().trim();

      if (fromUserId != null && fromUserId.isNotEmpty) {
        WidgetsFlutterBinding.ensureInitialized();
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }

        final firebaseAuth = FirebaseAuth.instance;
        if (firebaseAuth.currentUser == null) {
          try {
            await firebaseAuth
                .authStateChanges()
                .firstWhere((user) => user != null)
                .timeout(const Duration(seconds: 2));
          } catch (_) {}
        }

        final currentUserId = firebaseAuth.currentUser?.uid;
        if (currentUserId == null) return;

        final firestore = FirebaseFirestore.instance;

        if (actionId == 'accept_connection') {
          // Accept logic replicated from ConnectionsRepository
          final incomingRef = firestore
              .collection('users')
              .doc(currentUserId)
              .collection('incomingConnectionRequests')
              .doc(fromUserId);
          final outgoingRef = firestore
              .collection('users')
              .doc(fromUserId)
              .collection('outgoingConnectionRequests')
              .doc(currentUserId);

          final currentConnectionRef = firestore
              .collection('users')
              .doc(currentUserId)
              .collection('connections')
              .doc(fromUserId);
          final otherConnectionRef = firestore
              .collection('users')
              .doc(fromUserId)
              .collection('connections')
              .doc(currentUserId);

          final currentUserRef =
              firestore.collection('users').doc(currentUserId);
          final otherUserRef = firestore.collection('users').doc(fromUserId);

          final batch = firestore.batch();
          batch.delete(incomingRef);
          batch.delete(outgoingRef);

          final now = FieldValue.serverTimestamp();
          batch.set(
              currentConnectionRef, {'userId': fromUserId, 'createdAt': now});
          batch.set(
              otherConnectionRef, {'userId': currentUserId, 'createdAt': now});
          batch.update(
              currentUserRef, {'connectionsCount': FieldValue.increment(1)});
          batch.update(
              otherUserRef, {'connectionsCount': FieldValue.increment(1)});

          // Send acceptance notification to the sender
          final acceptorDoc = await currentUserRef.get();
          final acceptorData = acceptorDoc.data() ?? {};
          final acceptNotifId = 'conn_accept_${fromUserId}_$currentUserId';

          batch.set(
              firestore.collection('notifications').doc(acceptNotifId),
              {
                'toUserId': fromUserId,
                'fromUserId': currentUserId,
                'type': 'request_accepted',
                'createdAt': now,
                'read': false,
                if (acceptorData['name'] != null)
                  'senderName': acceptorData['name'],
                if (acceptorData['avatarUrl'] != null)
                  'senderAvatarUrl': acceptorData['avatarUrl'],
              },
              SetOptions(merge: true));

          // Removed the immediate deletion snippet here to mirror behavior

          await batch.commit();
        } else {
          // Decline logic
          final batch = firestore.batch();
          batch.delete(firestore
              .collection('users')
              .doc(currentUserId)
              .collection('incomingConnectionRequests')
              .doc(fromUserId));
          batch.delete(firestore
              .collection('users')
              .doc(fromUserId)
              .collection('outgoingConnectionRequests')
              .doc(currentUserId));
          if (notificationId != null && notificationId.isNotEmpty) {
            batch.delete(
                firestore.collection('notifications').doc(notificationId));
          }
          await batch.commit();
        }

        final flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin.cancel(id: response.id ?? 0);
        return;
      }
    }

    final postId = data['postId']?.toString().trim();
    if (postId == null || postId.isEmpty) return;

    if (actionId == 'approve_post' ||
        actionId == 'reject_post' ||
        actionId == 'like_post' ||
        actionId == 'laugh_post' ||
        actionId == 'support_post') {
      // Must initialize Firebase inside the background isolate
      WidgetsFlutterBinding.ensureInitialized();
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      final firebaseAuth = FirebaseAuth.instance;
      if (firebaseAuth.currentUser == null) {
        // Wait up to 2 seconds for the user session to be restored from disk
        try {
          await firebaseAuth
              .authStateChanges()
              .firstWhere((user) => user != null)
              .timeout(const Duration(seconds: 2));
        } catch (_) {}
      }

      final uid = firebaseAuth.currentUser?.uid;
      if (uid == null) {
        debugPrint('[BG-FCM] Background tap failed: User is unauthenticated.');
        return;
      }

      final firestore = FirebaseFirestore.instance;

      if (actionId == 'like_post' ||
          actionId == 'laugh_post' ||
          actionId == 'support_post') {
        final postRef = firestore.collection('posts').doc(postId);
        await firestore.runTransaction((transaction) async {
          final postDoc = await transaction.get(postRef);
          if (!postDoc.exists) return;

          final data = postDoc.data() as Map<String, dynamic>;
          final likedBy = List<String>.from(data['likedBy'] ?? []);
          final laughedBy = List<String>.from(data['laughedBy'] ?? []);
          final supportedBy = List<String>.from(data['supportedBy'] ?? []);

          final wasLiked = likedBy.contains(uid);
          final wasLaughed = laughedBy.contains(uid);
          final wasSupported = supportedBy.contains(uid);

          likedBy.remove(uid);
          laughedBy.remove(uid);
          supportedBy.remove(uid);

          if (actionId == 'like_post' && !wasLiked) {
            likedBy.add(uid);
          } else if (actionId == 'laugh_post' && !wasLaughed) {
            laughedBy.add(uid);
          } else if (actionId == 'support_post' && !wasSupported) {
            supportedBy.add(uid);
          }

          transaction.update(postRef, {
            'likedBy': likedBy,
            'laughedBy': laughedBy,
            'supportedBy': supportedBy,
            'likesCount': likedBy.length,
            'laughedCount': laughedBy.length,
            'supportedCount': supportedBy.length,
          });
        });

        final flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin.cancel(id: response.id ?? 0);
        return;
      }

      final status = actionId == 'approve_post' ? 'approved' : 'rejected';
      final type =
          actionId == 'approve_post' ? 'post_approved' : 'post_rejected';

      await firestore
          .collection('posts')
          .doc(postId)
          .update({'status': status});

      // Notify user
      final postDoc = await firestore.collection('posts').doc(postId).get();
      final postData = postDoc.data() ?? {};
      final ownerId = postData['userId'] as String? ?? '';

      if (ownerId.isNotEmpty && ownerId != uid) {
        final adminDoc = await firestore.collection('users').doc(uid).get();
        final adminData = adminDoc.data() ?? {};
        final senderName = adminData['name'] as String? ?? 'Admin';
        final senderAvatar = adminData['avatarUrl'] as String? ?? '';

        await firestore
            .collection('notifications')
            .doc('status_${postId}_$type')
            .set({
          'toUserId': ownerId,
          'fromUserId': uid,
          'postId': postId,
          'type': type,
          'text': postData['text'],
          'createdAt': Timestamp.now(),
          'read': false,
          if (senderName.isNotEmpty) 'senderName': senderName,
          if (senderAvatar.isNotEmpty) 'senderAvatarUrl': senderAvatar,
        }, SetOptions(merge: true));
      }

      // Close the notification
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin.cancel(id: response.id ?? 0);
    }
  } catch (e) {
    debugPrint('[BG-FCM] Background tap error: $e');
  }
}

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? _navigatorKey;
  NotificationResponse? _deferredLaunchResponse;
  Map<String, dynamic>? _deferredLaunchData;

  // ========== متغيرات اللغة ==========
  String _userLocale = 'en';
  // ===================================

  void processDeferredLaunchData() {
    if (_deferredLaunchData != null) {
      final data = _deferredLaunchData!;
      _deferredLaunchData = null;
      _handleTapData(data);
    }
    if (_deferredLaunchResponse != null) {
      final response = _deferredLaunchResponse!;
      _deferredLaunchResponse = null;
      _onLocalNotificationTap(response);
    }
  }

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _inAppNotificationsSub;

  String? _userId;
  String? _currentToken;
  DateTime? _inAppStartedAt;
  String? _lastInAppNotificationId;
  bool? _isAdmin;
  DateTime? _isAdminFetchedAt;

  static const _channelId = 'general';
  static const _channelName = 'General';
  static const _channelDescription = 'General notifications';
  static final FlutterLocalNotificationsPlugin _backgroundLocalNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _backgroundNotificationsReady = false;

  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleDeferredLaunchResponseIfAny();
    });
  }

  void _handleDeferredLaunchResponseIfAny() {
    final response = _deferredLaunchResponse;
    if (response == null) return;
    _deferredLaunchResponse = null;
    _onLocalNotificationTap(response);
  }

  static Future<void> _ensureBackgroundLocalNotificationsInitialized() async {
    if (_backgroundNotificationsReady) return;
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _backgroundLocalNotifications.initialize(
      settings: settings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
    final androidPlugin =
        _backgroundLocalNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
    }
    _backgroundNotificationsReady = true;
    // ignore: avoid_print
    print('[BG-FCM] flutter_local_notifications initialized OK');
  }

  static Future<void> showBackgroundNotification(RemoteMessage message) async {
    try {
      await _ensureBackgroundLocalNotificationsInitialized();
    } catch (e) {
      // ignore: avoid_print
      print('[BG-FCM] FAILED to init local notifications: $e');
      rethrow;
    }

    final data = message.data;

    final conversationId = (data['conversationId']?.toString() ?? '').trim();
    final toUserId = (data['toUserId']?.toString() ?? '').trim();
    final type = (data['type']?.toString() ?? '').trim();

    if (type == 'chat_message' &&
        conversationId.isNotEmpty &&
        toUserId.isNotEmpty) {
      try {
        final convDoc = await FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .get();
        if (convDoc.exists) {
          final convData = convDoc.data();
          if (convData != null) {
            final archivedBy =
                Map<String, dynamic>.from(convData['archivedBy'] ?? {});
            if (archivedBy[toUserId] == true) {
              // ignore: avoid_print
              print(
                  '[BG-FCM] Suppressed background notification for archived chat $conversationId');
              return;
            }
            final muteUntilVal = convData['muteUntil']?[toUserId];
            if (muteUntilVal is Timestamp) {
              if (muteUntilVal.toDate().isAfter(DateTime.now())) {
                // ignore: avoid_print
                print(
                    '[BG-FCM] Suppressed background notification for muted chat $conversationId');
                return;
              }
            }
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[BG-FCM] Error checking archive/mute in background: $e');
      }
    }
    final notification = message.notification;

    final title = (data['title']?.toString() ?? '').trim();
    final body = (data['body']?.toString() ?? '').trim();
    final resolvedTitle = title.isEmpty
        ? (notification?.title?.toString().trim().isNotEmpty == true
            ? notification!.title!
            : 'إشعار جديد')
        : title;
    final resolvedBody = body.isEmpty
        ? (notification?.body?.toString().trim().isNotEmpty == true
            ? notification!.body!
            : 'لديك إشعار جديد')
        : body;

    final avatarUrl = _extractAvatarUrl(data);
    final contentImageUrl = _extractContentImageUrl(data);

    Uint8List? avatarBytes;
    Uint8List? bigImageBytes;

    try {
      // 3-second timeout is critical for background isolate to survive Doze mode
      avatarBytes = await _downloadImageBytes(avatarUrl, timeoutSeconds: 3);
      bigImageBytes =
          await _downloadImageBytes(contentImageUrl, timeoutSeconds: 3);
    } catch (e) {
      // ignore: avoid_print
      print('[BG-FCM] Image download failed, falling back to text only: $e');
    }

    // ignore: avoid_print
    print(
        '[BG-FCM] Showing: "$resolvedTitle" / "$resolvedBody" (Avatar: ${avatarBytes != null}, Image: ${bigImageBytes != null})');

    List<AndroidNotificationAction>? actions;
    if (type == 'post_pending') {
      actions = [
        const AndroidNotificationAction('review_post', 'Review',
            showsUserInterface: true),
        const AndroidNotificationAction('approve_post', 'Approve',
            showsUserInterface: false),
        const AndroidNotificationAction('reject_post', 'Reject',
            showsUserInterface: false),
      ];
    } else if (type == 'comment' ||
        type == 'reply' ||
        type == 'mention' ||
        type == 'post_mention') {
      actions = [
        const AndroidNotificationAction('reply_comment', 'Reply',
            showsUserInterface: true),
        const AndroidNotificationAction('like_post', 'Like',
            showsUserInterface: false),
        const AndroidNotificationAction('laugh_post', 'Laugh',
            showsUserInterface: false),
      ];
    } else if (data['postId'] != null &&
        data['postId'].toString().trim().isNotEmpty) {
      actions = [
        const AndroidNotificationAction('like_post', 'Like',
            showsUserInterface: false),
        const AndroidNotificationAction('laugh_post', 'Laugh',
            showsUserInterface: false),
        const AndroidNotificationAction('support_post', 'Support',
            showsUserInterface: false),
      ];
    } else if (type == 'connection_request') {
      actions = [
        const AndroidNotificationAction('accept_connection', 'Accept',
            showsUserInterface: false),
        const AndroidNotificationAction('decline_connection', 'Decline',
            showsUserInterface: false),
      ];
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      largeIcon:
          avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null,
      styleInformation: bigImageBytes != null
          ? BigPictureStyleInformation(
              ByteArrayAndroidBitmap(bigImageBytes),
              largeIcon: avatarBytes != null
                  ? ByteArrayAndroidBitmap(avatarBytes)
                  : null,
              contentTitle: resolvedTitle,
              summaryText: resolvedBody,
            )
          : BigTextStyleInformation(resolvedBody),
      category: AndroidNotificationCategory.social,
      actions: actions,
    );
    const iosDetails = DarwinNotificationDetails();

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      await _backgroundLocalNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: resolvedTitle,
        body: resolvedBody,
        notificationDetails: details,
        payload: jsonEncode(data),
      );
    } catch (e) {
      // ignore: avoid_print
      print('[BG-FCM] FAILED to show notification: $e');
      rethrow;
    }
  }

  Future<void> initialize() async {
    await _loadUserLocale();
    await _requestPermissions();
    await _setupLocalNotifications();
    await _setupHandlers();
    await _syncTokenIfPossible();
  }

  // ========== دالة تحميل لغة المستخدم ==========
  Future<void> _loadUserLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userLocale = prefs.getString('language') ?? 'en';
      debugPrint('[PushNotificationsService] User locale: $_userLocale');
    } catch (_) {
      _userLocale = 'en';
    }
  }

  // ========== دالة تحديث لغة المستخدم ==========
  Future<void> setUserLocale(String locale) async {
    _userLocale = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language', locale);
      debugPrint('[PushNotificationsService] User locale updated to: $locale');
    } catch (_) {}
  }
  // =============================================

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    _isAdmin = null;
    _isAdminFetchedAt = null;
    await _syncTokenIfPossible();
    await _restartInAppNotificationsListener();
  }

  Future<void> subscribeToAcademicTopic({
    required String universityKey,
    required String departmentKey,
    required String levelKey,
  }) async {
    final topic = 'schedules_${universityKey}_${departmentKey}_$levelKey';
    try {
      await _messaging.subscribeToTopic(topic);
      // ignore: avoid_print
      print('[BG-FCM] Subscribed to topic: $topic');
    } catch (e) {
      // ignore: avoid_print
      print('[BG-FCM] Failed to subscribe to topic: $e');
    }
  }

  Future<void> clearUser() async {
    final userId = _userId;
    final token = _currentToken;
    _userId = null;
    await _inAppNotificationsSub?.cancel();
    _inAppNotificationsSub = null;
    _inAppStartedAt = null;
    _lastInAppNotificationId = null;
    _isAdmin = null;
    _isAdminFetchedAt = null;
    if (userId != null && token != null) {
      await _firestore.collection('users').doc(userId).set(
        {
          'fcmTokens': FieldValue.arrayRemove([token]),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedAppSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _inAppNotificationsSub?.cancel();
  }

  Future<void> _restartInAppNotificationsListener() async {
    await _inAppNotificationsSub?.cancel();
    _inAppNotificationsSub = null;
    _lastInAppNotificationId = null;
    _inAppStartedAt = DateTime.now();
    _listenInAppNotifications();
  }

  Future<bool> _getIsAdmin() async {
    final userId = _userId;
    if (userId == null) return false;
    final cached = _isAdmin;
    final at = _isAdminFetchedAt;
    if (cached != null && at != null) {
      final age = DateTime.now().difference(at);
      if (age.inMinutes < 10) return cached;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final role = (doc.data()?['role'] as String?)?.trim().toLowerCase();
      final isAdmin = role == 'admin';
      _isAdmin = isAdmin;
      _isAdminFetchedAt = DateTime.now();
      return isAdmin;
    } catch (_) {
      return false;
    }
  }

  void _listenInAppNotifications() {
    final userId = _userId;
    if (userId == null) {
      debugPrint(
          'PushNotificationsService: No userId to listen for notifications');
      return;
    }

    debugPrint(
        'PushNotificationsService: Starting in-app listener for user: $userId');

    _inAppNotificationsSub = _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      debugPrint(
          'PushNotificationsService: Received notification snapshot with ${snap.docs.length} docs');
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final id = doc.id;
      if (_lastInAppNotificationId == id) {
        debugPrint(
            'PushNotificationsService: Skipping duplicate notification ID: $id');
        return;
      }

      final data = doc.data();
      final type = data['type']?.toString().trim() ?? '';
      final fromUid = (data['fromUserId']?.toString() ?? '').trim();
      final uidTrim = userId.trim();

      final conversationId = (data['conversationId']?.toString() ?? '').trim();
      if (type == 'chat_message' && conversationId.isNotEmpty) {
        try {
          final convDoc = await _firestore
              .collection('conversations')
              .doc(conversationId)
              .get();
          if (convDoc.exists) {
            final convData = convDoc.data();
            if (convData != null) {
              final archivedBy =
                  Map<String, dynamic>.from(convData['archivedBy'] ?? {});
              if (archivedBy[uidTrim] == true) {
                debugPrint(
                    'PushNotificationsService: Suppressed notification for archived chat $conversationId');
                try {
                  await doc.reference.update({'read': true});
                } catch (e) {
                  debugPrint(
                      'PushNotificationsService: mark read failed for archived chat: $e');
                }
                return;
              }
              final muteUntilVal = convData['muteUntil']?[uidTrim];
              if (muteUntilVal is Timestamp) {
                if (muteUntilVal.toDate().isAfter(DateTime.now())) {
                  debugPrint(
                      'PushNotificationsService: Suppressed notification for muted chat $conversationId');
                  try {
                    await doc.reference.update({'read': true});
                  } catch (e) {
                    debugPrint(
                        'PushNotificationsService: mark read failed for muted chat: $e');
                  }
                  return;
                }
              }
            }
          }
        } catch (e) {
          debugPrint(
              'PushNotificationsService: Error checking archive/mute: $e');
        }
      }

      final groupId = (data['groupId']?.toString() ?? '').trim();
      // Only group chat: hide local banner for your own message (must have groupId).
      if (fromUid.isNotEmpty &&
          fromUid == uidTrim &&
          groupId.isNotEmpty &&
          (type == 'group_message' || type == 'group_mention')) {
        debugPrint(
          'PushNotificationsService: Skip in-app group notification — sender is current user',
        );
        try {
          await doc.reference.update({'read': true});
        } catch (e) {
          debugPrint('PushNotificationsService: mark read failed: $e');
        }
        return;
      }

      _lastInAppNotificationId = id;

      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final startedAt = _inAppStartedAt;

      debugPrint(
          'PushNotificationsService: Processing notification: $id, type: ${data['type']}');

      if (startedAt != null &&
          createdAt != null &&
          createdAt.isBefore(startedAt)) {
        debugPrint(
            'PushNotificationsService: Skipping old notification created at $createdAt (started at $startedAt)');
        return;
      }

      final text = _composeNotificationText(data);
      final title = text['title'] ?? 'Uni-Hub';
      final body = text['body'] ?? '';
      final avatarUrl = _extractAvatarUrl(data);
      final contentImageUrl = _extractContentImageUrl(data);

      final payload = jsonEncode(_buildTapPayload(data, overrideType: type));

      debugPrint(
          'PushNotificationsService: Showing local notification: $title - $body');
      await _showLocalNotification(
        title: title,
        body: body,
        payload: payload,
        avatarUrl: avatarUrl,
        contentImageUrl: contentImageUrl,
      );
    }, onError: (error) {
      debugPrint(
          'PushNotificationsService: Error in notifications listener: $error');
      // إذا كان هناك خطأ في الفهرس (Index)، سيظهر الرابط هنا في سجلات الـ Debug
    });
  }

  Map<String, dynamic> _buildTapPayload(
    Map<String, dynamic> data, {
    String? overrideType,
  }) {
    String? normalizeString(dynamic v) {
      final s = (v?.toString() ?? '').trim();
      return s.isEmpty ? null : s;
    }

    final type = (overrideType ?? data['type']?.toString() ?? '').trim();
    final postId = normalizeString(data['postId']);
    final commentId = normalizeString(data['commentId']);
    final parentCommentId = normalizeString(data['parentCommentId']);
    final notificationId =
        normalizeString(data['notificationId'] ?? data['id']);

    return {
      if (type.isNotEmpty) 'type': type,
      if (postId != null) 'postId': postId,
      if (commentId != null) 'commentId': commentId,
      if (parentCommentId != null) 'parentCommentId': parentCommentId,
      if (notificationId != null) 'notificationId': notificationId,
      if (data['conversationId'] != null)
        'conversationId': data['conversationId']?.toString(),
      if (data['fromUserId'] != null)
        'fromUserId': data['fromUserId']?.toString(),
      if (data['senderName'] != null)
        'senderName': data['senderName']?.toString(),
      if (data['senderAvatarUrl'] != null)
        'senderAvatarUrl': data['senderAvatarUrl']?.toString(),
      if (data['universityKey'] != null)
        'universityKey': data['universityKey']?.toString(),
      if (data['departmentKey'] != null)
        'departmentKey': data['departmentKey']?.toString(),
      if (data['levelKey'] != null) 'levelKey': data['levelKey']?.toString(),
      // Community join-request extras
      if (data['communityId'] != null)
        'communityId': data['communityId']?.toString(),
      if (data['communityName'] != null)
        'communityName': data['communityName']?.toString(),
      if (data['requestId'] != null) 'requestId': data['requestId']?.toString(),
    };
  }

  // ========== التحقق من وجود أحرف عربية ==========
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;
    final arabicRegex = RegExp(
        r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicRegex.hasMatch(text);
  }

  // ========== ترجمة النص حسب اللغة ==========
  String _getLocalizedText(String enText, String arText) {
    // إذا كانت لغة المستخدم عربية أو النص يحتوي على عربي
    if (_userLocale == 'ar' || _isArabicText(enText)) {
      return arText;
    }
    return enText;
  }
  // ============================================

  /// ============================================================
  /// ✅ دالة تجميع نص الإشعار - دعم كامل للغة مع post_mention
  /// ============================================================
  Map<String, String> _composeNotificationText(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim() ?? '';
    final senderName = data['senderName']?.toString().trim().isNotEmpty == true
        ? data['senderName']!.toString().trim()
        : 'Uni-Hub';
    final snippet = (data['text']?.toString() ?? '').trim();
    // ========== جلب نص المنشور من postText ==========
    final postText = (data['postText']?.toString() ?? '').trim();
    // ===============================================

    switch (type) {
      case 'chat_message':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? snippet
              : _getLocalizedText('Sent you a message', 'أرسل لك رسالة'),
        };
      case 'group_message':
        final groupName = (data['groupName']?.toString() ?? '').trim();
        return {
          'title': groupName.isNotEmpty ? groupName : senderName,
          'body': snippet.isNotEmpty
              ? '$senderName: $snippet'
              : _getLocalizedText(
                  '$senderName sent a message', '$senderName أرسل رسالة'),
        };
      case 'group_mention':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Mentioned you: $snippet', 'ذكرك: $snippet')
              : _getLocalizedText('Mentioned you in a group', 'ذكرك في مجموعة'),
        };
      case 'comment':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Commented on your post: $snippet',
                  'علّق على منشورك: $snippet')
              : _getLocalizedText('Commented on your post', 'علّق على منشورك'),
        };
      case 'reply':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Replied to your comment: $snippet',
                  'ردّ على تعليقك: $snippet')
              : _getLocalizedText('Replied to your comment', 'ردّ على تعليقك'),
        };
      case 'like':
        return {
          'title': senderName,
          'body': _getLocalizedText('Liked your post', 'أعجب بمنشورك'),
        };
      case 'laugh':
        return {
          'title': senderName,
          'body': _getLocalizedText(
              'Laughed at your post 😂', 'تفاعل 😂 مع منشورك'),
        };
      case 'support':
        return {
          'title': senderName,
          'body': _getLocalizedText(
              'Supported your post ❤️', 'قدّم الدعم ❤️ لمنشورك'),
        };
      case 'repost':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Reposted your post: $snippet',
                  'أعاد نشر منشورك مع: $snippet')
              : _getLocalizedText('Reposted your post', 'أعاد نشر منشورك'),
        };
      case 'comment_like':
        return {
          'title': senderName,
          'body': _getLocalizedText('Liked your comment', 'أعجب بتعليقك'),
        };
      case 'mention':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Mentioned you in a comment: $snippet',
                  'ذكرك في تعليق: $snippet')
              : _getLocalizedText(
                  'Mentioned you in a comment', 'ذكرك في تعليق'),
        };

      /// ============================================================
      /// ✅ post_mention - يعرض اسم المرسل + نص المنشور
      /// ============================================================
      case 'post_mention':
        // استخدام postText أولاً، ثم snippet كاحتياطي
        final displayText = postText.isNotEmpty ? postText : snippet;
        return {
          'title': senderName,
          'body': displayText.isNotEmpty
              ? _getLocalizedText(
                  'mentioned you in a post: $displayText',
                  'ذكرك في منشور: $displayText')
              : _getLocalizedText('mentioned you in a post', 'ذكرك في منشور'),
        };
      /// ============================================================

      case 'post_pending':
        return {
          'title': senderName,
          'body': snippet.isNotEmpty
              ? _getLocalizedText('Submitted a post for approval: $snippet',
                  'قدّم منشوراً للموافقة: $snippet')
              : _getLocalizedText(
                  'Submitted a post for approval', 'قدّم منشوراً للموافقة'),
        };
      case 'post_approved':
        return {
          'title': _getLocalizedText('✅ Great news!', '✅ أخبار سارة!'),
          'body': _getLocalizedText(
              'Your post has been approved and is now live.',
              'تم قبول منشورك وهو الآن متاح للجميع.'),
        };
      case 'post_rejected':
        return {
          'title': _getLocalizedText('⚠️ Update needed', '⚠️ تعديل مطلوب'),
          'body': _getLocalizedText(
              'Your post was not approved. Click to see why.',
              'لم يتم قبول منشورك. اضغط لمعرفة السبب.'),
        };
      case 'community_join_request':
        {
          final communityName =
              (data['communityName']?.toString() ?? '').trim();
          return {
            'title': _getLocalizedText(
                'Join request — ${communityName.isNotEmpty ? communityName : 'Community'}',
                'طلب انضمام — ${communityName.isNotEmpty ? communityName : 'المجتمع'}'),
            'body': _getLocalizedText(
                '$senderName wants to join', '$senderName يطلب الانضمام'),
          };
        }
      case 'schedule_uploaded':
        return {
          'title': _getLocalizedText('Lecture Schedule', 'جدول المحاضرات'),
          'body': _getLocalizedText('A new lecture schedule is now available.',
              'يتوفر الآن جدول محاضرات جديد.'),
        };
      case 'connection_request':
        return {
          'title':
              _getLocalizedText('New Connection Request', 'طلب تواصل جديد'),
          'body': _getLocalizedText(
              '$senderName sent you a connection request.',
              'أرسل لك $senderName طلب تواصل.'),
        };
      case 'request_accepted':
        return {
          'title': _getLocalizedText('Request Accepted', 'تم قبول طلبك'),
          'body': _getLocalizedText(
              '$senderName accepted your connection request.',
              'قام $senderName بقبول طلب التواصل الخاص بك.'),
        };
      default:
        return {
          'title': _getLocalizedText('New Notification', 'إشعار جديد'),
          'body': _getLocalizedText(
              'You have a new notification', 'لديك إشعار جديد'),
        };
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _setupLocalNotifications() async {
    // Use a monochrome drawable — @mipmap/ic_launcher fails on Android 5+ notification channels
    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) &&
        launchResponse != null) {
      _deferredLaunchResponse = launchResponse;
    }

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ),
        );
  }

  Future<void> _setupHandlers() async {
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
      final data = message.data;
      final type = (data['type']?.toString() ?? '').trim();
      final fromUid = (data['fromUserId']?.toString() ?? '').trim();
      final myUid = (_userId ?? '').trim();
      if (myUid.isNotEmpty &&
          fromUid == myUid &&
          (type == 'group_message' || type == 'group_mention')) {
        debugPrint('[FCM foreground] Skip group notification — own message');
        return;
      }

      final notification = message.notification;
      final fallback = _composeNotificationText(message.data);
      final title = notification?.title ?? fallback['title'];
      final body = notification?.body ?? fallback['body'];
      if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
        return;
      }
      final notificationId = (data['notificationId']?.toString() ?? '').trim();
      if (notificationId.isNotEmpty) {
        _lastInAppNotificationId = notificationId;
      }
      final payload = jsonEncode(_buildTapPayload(data));
      final avatarUrl = _extractAvatarUrl(message.data);
      final contentImageUrl = _extractContentImageUrl(message.data);
      await _showLocalNotification(
        title: title ?? 'Notification',
        body: body ?? '',
        payload: payload,
        avatarUrl: avatarUrl,
        contentImageUrl: contentImageUrl,
      );
    });

    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      Future.microtask(() => _handleTapData(message.data));
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _deferredLaunchData = initialMessage.data;
    }

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) async {
      _currentToken = token.trim().isEmpty ? null : token.trim();
      await _syncTokenIfPossible();
    });
  }

  Future<void> _syncTokenIfPossible() async {
    final userId = _userId;
    if (userId == null) return;

    _currentToken ??= (await _messaging.getToken())?.trim();
    final token = _currentToken;
    if (token == null || token.isEmpty) return;

    await _firestore.collection('users').doc(userId).set(
      {
        'fcmTokens': FieldValue.arrayUnion([token]),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    String? avatarUrl,
    String? contentImageUrl,
  }) async {
    final avatarBytes = await _downloadImageBytes(avatarUrl);
    final bigImageBytes = await _downloadImageBytes(contentImageUrl);

    String? type;
    try {
      final decoded = jsonDecode(payload);
      type = decoded['type']?.toString();
    } catch (_) {}

    List<AndroidNotificationAction>? actions;
    if (type == 'post_pending') {
      actions = [
        const AndroidNotificationAction('review_post', 'Review',
            showsUserInterface: true),
        const AndroidNotificationAction('approve_post', 'Approve',
            showsUserInterface: false),
        const AndroidNotificationAction('reject_post', 'Reject',
            showsUserInterface: false),
      ];
    } else if (type == 'comment' ||
        type == 'reply' ||
        type == 'mention' ||
        type == 'post_mention') {
      actions = [
        const AndroidNotificationAction('reply_comment', 'Reply',
            showsUserInterface: true),
        const AndroidNotificationAction('like_post', 'Like Post',
            showsUserInterface: false),
      ];
    } else {
      String? postId;
      try {
        final decoded = jsonDecode(payload);
        postId = decoded['postId']?.toString().trim();
      } catch (_) {}

      if (postId != null && postId.isNotEmpty) {
        actions = [
          const AndroidNotificationAction('like_post', 'Like',
              showsUserInterface: false),
          const AndroidNotificationAction('laugh_post', 'Laugh',
              showsUserInterface: false),
          const AndroidNotificationAction('support_post', 'Support',
              showsUserInterface: false),
        ];
      }
    }

    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      largeIcon:
          avatarBytes != null ? ByteArrayAndroidBitmap(avatarBytes) : null,
      styleInformation: bigImageBytes != null
          ? BigPictureStyleInformation(
              ByteArrayAndroidBitmap(bigImageBytes),
              largeIcon: avatarBytes != null
                  ? ByteArrayAndroidBitmap(avatarBytes)
                  : null,
              contentTitle: title,
              summaryText: body,
            )
          : BigTextStyleInformation(body),
      actions: actions,
    );
    const ios = DarwinNotificationDetails();
    final details = NotificationDetails(android: android, iOS: ios);
    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  static String? _extractAvatarUrl(Map<String, dynamic> data) {
    const keys = <String>[
      'senderAvatarUrl',
      'avatarUrl',
      'userAvatarUrl',
    ];
    for (final key in keys) {
      final value = (data[key]?.toString() ?? '').trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
    return null;
  }

  static String? _extractContentImageUrl(Map<String, dynamic> data) {
    const keys = <String>[
      'imageUrl',
      'postImageUrl',
      'contentImageUrl',
    ];
    for (final key in keys) {
      final value = (data[key]?.toString() ?? '').trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return value;
      }
    }
    return null;
  }

  static Future<Uint8List?> _downloadImageBytes(String? url,
      {int timeoutSeconds = 6}) async {
    if (url == null || url.isEmpty) return null;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
        return null;
      }
      final response =
          await http.get(uri).timeout(Duration(seconds: timeoutSeconds));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// ============================================================
  ///   دالة معالجة الضغط على الإشعار - تم إضافة post_mention
  /// ============================================================
  void _onLocalNotificationTap(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload == null || payload.isEmpty) return;
    try {
      final data = decodeNotificationPayload(payload);
      if (data == null) return;

      debugPrint(
        '[NotifNav] local tap actionId=$actionId type=${data['type']} postId=${data['postId']}',
      );

      final postId = data['postId']?.toString().trim();
      if (postId != null &&
          postId.isNotEmpty &&
          (actionId == 'approve_post' ||
              actionId == 'reject_post' ||
              actionId == 'like_post')) {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          final firestore = FirebaseFirestore.instance;

          if (actionId == 'like_post') {
            final postRef = firestore.collection('posts').doc(postId);
            await firestore.runTransaction((transaction) async {
              final postDoc = await transaction.get(postRef);
              if (!postDoc.exists) return;

              final postData = postDoc.data() as Map<String, dynamic>;
              final likedBy = List<String>.from(postData['likedBy'] ?? []);
              final laughedBy = List<String>.from(postData['laughedBy'] ?? []);
              final supportedBy =
                  List<String>.from(postData['supportedBy'] ?? []);

              final wasLiked = likedBy.contains(uid);
              likedBy.remove(uid);
              laughedBy.remove(uid);
              supportedBy.remove(uid);

              if (!wasLiked) {
                likedBy.add(uid);
              }

              transaction.update(postRef, {
                'likedBy': likedBy,
                'laughedBy': laughedBy,
                'supportedBy': supportedBy,
                'likesCount': likedBy.length,
                'laughedCount': laughedBy.length,
                'supportedCount': supportedBy.length,
              });
            });

            await _localNotifications.cancel(id: response.id ?? 0);
            return;
          }

          final status = actionId == 'approve_post' ? 'approved' : 'rejected';
          final type =
              actionId == 'approve_post' ? 'post_approved' : 'post_rejected';

          await firestore
              .collection('posts')
              .doc(postId)
              .update({'status': status});

          final postDoc = await firestore.collection('posts').doc(postId).get();
          final postData = postDoc.data() ?? {};
          final ownerId = postData['userId'] as String? ?? '';

          if (ownerId.isNotEmpty && ownerId != uid) {
            final adminDoc = await firestore.collection('users').doc(uid).get();
            final adminData = adminDoc.data() ?? {};
            final senderName = adminData['name'] as String? ?? 'Admin';
            final senderAvatar = adminData['avatarUrl'] as String? ?? '';

            await firestore
                .collection('notifications')
                .doc('status_${postId}_$type')
                .set({
              'toUserId': ownerId,
              'fromUserId': uid,
              'postId': postId,
              'type': type,
              'text': postData['text'],
              'createdAt': Timestamp.now(),
              'read': false,
              if (senderName.isNotEmpty) 'senderName': senderName,
              if (senderAvatar.isNotEmpty) 'senderAvatarUrl': senderAvatar,
            }, SetOptions(merge: true));
          }
          await _localNotifications.cancel(id: response.id ?? 0);
        }
        return; // Don't navigate
      }

      if (actionId == 'review_post' && postId != null && postId.isNotEmpty) {
        final nav = _navigatorKey?.currentState;
        if (nav == null) {
          _deferredLaunchResponse ??= response;
          debugPrint('[NotifNav] review_post deferred: navigator not ready');
          return;
        }
        debugPrint(
            '[NotifNav] pushing PostDetailScreen for review postId=$postId');
        nav.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: postId,
              focusCommentInput: false,
            ),
          ),
        );
        return;
      }

      Future.microtask(() => _handleTapData(data));
    } catch (e, st) {
      debugPrint('[NotifNav] _onLocalNotificationTap error: $e\n$st');
    }
  }

  /// ============================================================
  ///  دالة معالجة الضغط على البيانات - تم إضافة post_mention
  /// ============================================================
  Future<void> _handleTapData(Map<String, dynamic> data) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) {
      debugPrint('[NotifNav] _handleTapData skipped: navigator is null');
      return;
    }

    final type = data['type']?.toString().trim() ?? '';
    final conversationId = data['conversationId']?.toString().trim();

    debugPrint('[NotifNav] _handleTapData type=$type postId=${data['postId']}');

    if (type == 'chat_message' &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      final otherUserId = data['fromUserId']?.toString().trim() ?? '';
      final otherUserName = data['senderName']?.toString().trim() ?? 'User';
      final otherUserAvatar = data['senderAvatarUrl']?.toString().trim();

      nav.push(
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            conversationId: conversationId,
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            otherUserAvatar: otherUserAvatar,
          ),
        ),
      );
      return;
    }

    // ── Group message / mention ──────────────────────────────────────────────
    final groupId = data['groupId']?.toString().trim();
    if ((type == 'group_message' || type == 'group_mention') &&
        groupId != null &&
        groupId.isNotEmpty) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final senderName = data['senderName']?.toString().trim() ?? 'User';
      nav.push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: groupId,
            currentUserId: currentUid,
            currentUserName: senderName,
          ),
        ),
      );
      return;
    }

    if (type == 'schedule_uploaded') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => const LecturesSectionScreen(),
        ),
      );
      return;
    }

    if (type == 'post_pending') {
      final isAdmin = await _getIsAdmin();
      if (isAdmin) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => const AdminDashboardScreen(initialTabIndex: 0),
          ),
        );
        return;
      }
    }

    // ── Community join-request ───────────────────────────────────────────────
    if (type == 'community_join_request') {
      final communityId = data['communityId']?.toString().trim();
      if (communityId != null && communityId.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('communities')
              .doc(communityId)
              .get();
          if (snap.exists) {
            final community = CommunityModel.fromFirestore(snap).toEntity();
            nav.push(
              MaterialPageRoute(
                builder: (_) => CommunityDetailScreen(community: community),
              ),
            );
            return;
          }
        } catch (_) {}
      }
      // Fallback: open notifications screen
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      return;
    }

    /// ============================================================
    ///  معالجة إشعار المنشن في البوست (post_mention)
    /// ============================================================
    if (type == 'post_mention') {
      final postId = data['postId']?.toString().trim();
      if (postId != null && postId.isNotEmpty) {
        debugPrint('[NotifNav] Opening post from post_mention: $postId');
        nav.push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(
              postId: postId,
              focusCommentInput: false,
            ),
          ),
        );
        return;
      }
      // Fallback
      nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      return;
    }

    /// ============================================================

    final postId = data['postId']?.toString().trim();
    if (postId != null && postId.isNotEmpty) {
      final commentId = (data['commentId']?.toString() ?? '').trim();
      final targetCommentId = commentId.isNotEmpty ? commentId : null;

      debugPrint(
          '[NotifNav] pushing PostDetailScreen postId=$postId initialCommentId=$targetCommentId');

      nav.push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            postId: postId,
            initialCommentId: targetCommentId,
            focusCommentInput:
                type == 'comment' || type == 'reply' || type == 'mention',
          ),
        ),
      );
      return;
    }

    nav.push(
      MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
      ),
    );
  }
}