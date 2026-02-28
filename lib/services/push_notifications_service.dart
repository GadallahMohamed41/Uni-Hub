import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../features/home/post_detail_screen.dart';
import '../features/profile/lectures_section_screen.dart';
import '../features/profile/notifications_screen.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {}

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? _navigatorKey;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inAppNotificationsSub;

  String? _userId;
  String? _currentToken;
  DateTime? _inAppStartedAt;
  String? _lastInAppNotificationId;

  static const _channelId = 'general';
  static const _channelName = 'General';
  static const _channelDescription = 'General notifications';

  void attachNavigatorKey(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
  }

  Future<void> initialize() async {
    await _requestPermissions();
    await _setupLocalNotifications();
    await _setupHandlers();
    await _syncTokenIfPossible();
  }

  Future<void> setUserId(String? userId) async {
    _userId = userId;
    await _syncTokenIfPossible();
    await _restartInAppNotificationsListener();
  }

  Future<void> clearUser() async {
    final userId = _userId;
    final token = _currentToken;
    _userId = null;
    await _inAppNotificationsSub?.cancel();
    _inAppNotificationsSub = null;
    _inAppStartedAt = null;
    _lastInAppNotificationId = null;
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

  void _listenInAppNotifications() {
    final userId = _userId;
    if (userId == null) return;

    _inAppNotificationsSub = _firestore
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) async {
      if (snap.docs.isEmpty) return;
      final doc = snap.docs.first;
      final id = doc.id;
      if (_lastInAppNotificationId == id) return;
      _lastInAppNotificationId = id;

      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final startedAt = _inAppStartedAt;
      if (startedAt != null && createdAt != null && createdAt.isBefore(startedAt)) {
        return;
      }

      final type = data['type']?.toString().trim() ?? '';
      final title = type == 'schedule_uploaded' ? 'جدول المحاضرات' : 'إشعار جديد';
      final body = type == 'schedule_uploaded' ? 'تم رفع جدول جديد - اضغط للعرض' : 'لديك إشعار جديد';

      final payload = jsonEncode({
        'type': type,
        'postId': data['postId']?.toString(),
        'universityKey': data['universityKey']?.toString(),
        'departmentKey': data['departmentKey']?.toString(),
        'levelKey': data['levelKey']?.toString(),
      });

      await _showLocalNotification(title: title, body: body, payload: payload);
    });
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
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);
    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

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
      final notification = message.notification;
      final title = notification?.title;
      final body = notification?.body;
      if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
        return;
      }
      final payload = jsonEncode(message.data);
      await _showLocalNotification(
        title: title ?? 'Notification',
        body: body ?? '',
        payload: payload,
      );
    });

    _onMessageOpenedAppSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTapData(message.data);
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleTapData(initialMessage.data);
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
  }) async {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) {
        _handleTapData(data);
      }
    } catch (_) {}
  }

  void _handleTapData(Map<String, dynamic> data) {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final type = data['type']?.toString().trim();
    if (type == 'schedule_uploaded') {
      nav.push(
        MaterialPageRoute(
          builder: (_) => const LecturesSectionScreen(),
        ),
      );
      return;
    }

    final postId = data['postId']?.toString().trim();
    if (postId != null && postId.isNotEmpty) {
      nav.push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(postId: postId),
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
