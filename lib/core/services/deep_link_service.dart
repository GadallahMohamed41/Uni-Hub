import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/main.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/community/data/repositories/group_invite_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/community_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/presentation/screens/join_request_screen.dart';
import 'package:project_test2/features/community/presentation/screens/community_join_request_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_chat_screen.dart';
import 'package:project_test2/features/community/presentation/screens/community_detail_screen.dart';

/// DeepLinkService — production-grade cold-start safe implementation.
///
/// Architecture:
/// ┌──────────────────────────────────────────────────────────────┐
/// │  Platform                                                    │
/// │  (getInitialLink / uriLinkStream)                            │
/// └────────────────────┬─────────────────────────────────────────┘
///                      │ URI
/// ┌────────────────────▼─────────────────────────────────────────┐
/// │  _handleUri()  — validation + domain check + rate limit      │
/// └────────────────────┬─────────────────────────────────────────┘
///                      │ valid URI
/// ┌────────────────────▼─────────────────────────────────────────┐
/// │  _readinessCompleter.future  ← awaited here                  │
/// │  (completes when splash finishes + navigator mounted)        │
/// └────────────────────┬─────────────────────────────────────────┘
///                      │ app ready
/// ┌────────────────────▼─────────────────────────────────────────┐
/// │  _navigateToJoinFlow() / FilterStyleInviteSheet              │
/// └──────────────────────────────────────────────────────────────┘
class DeepLinkService {
  static final DeepLinkService instance = DeepLinkService._();
  DeepLinkService._();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // ── Readiness gate ─────────────────────────────────────────────────────────
  // The Completer is used instead of a boolean flag to make _handleUri()
  // fully async-safe: it simply awaits the future and resumes automatically
  // when markAppReady() is called — no polling, no timers, no race conditions.
  final Completer<void> _readinessCompleter = Completer<void>();

  // ── Duplicate navigation guard ─────────────────────────────────────────────
  // Tracks the last processed token to prevent the stream from firing twice
  // (e.g., both getInitialLink AND the stream emitting the same URI on Android).
  String? _lastProcessedToken;
  DateTime? _lastActionTime;

  // ── Validation helpers ─────────────────────────────────────────────────────
  bool _isValidUuid(String s) {
    final regex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return regex.hasMatch(s);
  }

  bool _isValidGroupId(String s) {
    if (s.length > 50) return false;
    final regex = RegExp(r'^[a-zA-Z0-9_-]+$');
    return regex.hasMatch(s);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Call this once from main.dart / _initDeferredServices().
  /// Safe to call after async gaps — does NOT require a BuildContext.
  void initializeWithNavigatorKey() {
    // 1. Subscribe to foreground/background link stream.
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        debugPrint('[DeepLinkService] Stream URI: $uri');
        _handleUri(uri);
      },
      onError: (err) {
        debugPrint('[DeepLinkService] Stream error: $err');
      },
    );

    // 2. Handle cold-start (terminated state) initial link.
    //    We intentionally do NOT await this — it runs in parallel.
    //    _handleUri will await _readinessCompleter internally.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('[DeepLinkService] Cold-start URI: $uri');
        _handleUri(uri);
      }
    }).catchError((err) {
      debugPrint('[DeepLinkService] getInitialLink error: $err');
    });
  }

  /// Call this from the splash screen AFTER navigation to the main screen
  /// and AFTER the new route's frame has been rendered.
  ///
  /// This completes the readiness gate, unblocking any pending _handleUri call.
  void markAppReady() {
    if (!_readinessCompleter.isCompleted) {
      debugPrint('[DeepLinkService] App marked as ready — unblocking pending links.');
      _readinessCompleter.complete();
    }
  }

  /// Publicly trigger the join flow for a given token (used by QR bottom sheet).
  void processToken(String token) {
    if (!_isValidUuid(token) && !_isValidGroupId(token)) {
      debugPrint('[DeepLinkService] processToken: invalid format: $token');
      return;
    }
    debugPrint('[DeepLinkService] processToken: $token');
    _navigateToJoinFlow(token);
  }

  /// Check for any pending link after the user logs in.
  /// This is a no-op now since _handleUri handles auth-gating internally,
  /// but kept for backward compatibility with AuthProvider.checkAuthState().
  void checkPendingLink() {
    // No-op: _handleUri awaits both readiness AND authentication inline.
    // Nothing to do here.
    debugPrint('[DeepLinkService] checkPendingLink called (no-op in new implementation).');
  }

  /// Stop listening to deep link streams.
  void dispose() {
    _linkSubscription?.cancel();
  }

  // ── Core routing logic ─────────────────────────────────────────────────────

  /// Fully async handler that awaits the readiness gate before navigating.
  /// This is the single entry point for ALL link sources (stream + initial link).
  Future<void> _handleUri(Uri uri) async {
    debugPrint('[DeepLinkService] Handling URI: $uri');

    // ── Step 1: Domain/scheme validation ─────────────────────────────────────
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host != 'university-connect-52779.web.app' &&
          uri.host != 'projectv2.web.app') {
        debugPrint('[DeepLinkService] Rejected spoofed domain: ${uri.host}');
        return;
      }
    } else if (uri.scheme != 'myapp') {
      debugPrint('[DeepLinkService] Rejected unknown scheme: ${uri.scheme}');
      return;
    }

    // ── Step 2: Parameter extraction ─────────────────────────────────────────
    String? token = uri.queryParameters['token'];
    if (token == null && uri.pathSegments.contains('invite')) {
      final inviteIndex = uri.pathSegments.indexOf('invite');
      if (inviteIndex + 1 < uri.pathSegments.length) {
        token = uri.pathSegments[inviteIndex + 1];
      }
    }

    final groupId = uri.queryParameters['groupId'];

    // ── Step 3: Format validation ─────────────────────────────────────────────
    if (token != null && !_isValidUuid(token) && !_isValidGroupId(token)) {
      debugPrint('[DeepLinkService] Malformed token rejected: $token');
      return;
    }

    if (groupId != null && !_isValidGroupId(groupId)) {
      debugPrint('[DeepLinkService] Malformed groupId rejected: $groupId');
      return;
    }

    if (token == null && groupId == null) {
      debugPrint('[DeepLinkService] No valid token or groupId in URI');
      return;
    }

    // ── Step 4: Duplicate navigation guard ───────────────────────────────────
    final dedupeKey = token ?? groupId!;
    final now = DateTime.now();

    if (_lastProcessedToken == dedupeKey &&
        _lastActionTime != null &&
        now.difference(_lastActionTime!).inSeconds < 5) {
      debugPrint('[DeepLinkService] Duplicate link suppressed: $dedupeKey');
      return;
    }

    // ── Step 5: Await app readiness (THE KEY FIX) ────────────────────────────
    // This single await replaces all the fragile boolean flag + pending URI
    // storage logic. No matter when this function is called (cold start,
    // foreground, background), it will simply wait here until markAppReady()
    // is called from the splash screen. There is no race condition because
    // Dart's async/await ensures ordered execution.
    debugPrint('[DeepLinkService] Awaiting app readiness...');
    await _readinessCompleter.future;
    debugPrint('[DeepLinkService] App is ready. Proceeding with navigation.');

    // ── Step 6: Await navigator readiness ────────────────────────────────────
    // After markAppReady(), the navigator should be mounted. We add a brief
    // frame wait to guarantee the new route (MainLayout) is fully mounted.
    await Future.delayed(const Duration(milliseconds: 200));

    // Re-fetch navigator state AFTER the await — rootNavigatorKey is a
    // GlobalKey so currentState/currentContext are always fresh references,
    // not captured BuildContext parameters, making this lint-safe.
    if (rootNavigatorKey.currentState == null ||
        rootNavigatorKey.currentContext == null) {
      debugPrint('[DeepLinkService] Navigator not ready after readiness gate. Aborting.');
      return;
    }

    // ── Step 7: Authentication check ─────────────────────────────────────────
    // ignore: use_build_context_synchronously — context is re-fetched live
    // from rootNavigatorKey.currentContext (never a stale captured parameter).
    final authProvider = Provider.of<AuthProvider>(
      // ignore: use_build_context_synchronously
      rootNavigatorKey.currentContext!,
      listen: false,
    );

    if (!authProvider.isAuthenticated) {
      debugPrint('[DeepLinkService] User not authenticated. Scheduling retry after login.');
      _scheduleRetryAfterAuth(token, groupId, uri);
      return;
    }

    // ── Step 8: Mark as processed (dedup) ────────────────────────────────────
    _lastProcessedToken = dedupeKey;
    _lastActionTime = now;

    // ── Step 9: Navigate ──────────────────────────────────────────────────────
    if (token != null) {
      await _navigateToJoinFlow(token);
    } else if (groupId != null) {
      _showErrorSnackBar('رابط الانضمام المباشر غير مدعوم. يرجى استخدام رابط دعوة.');
    }
  }

  /// Retry logic: polls authentication state and re-processes the link
  /// once the user logs in (e.g., when app cold-starts to login screen).
  void _scheduleRetryAfterAuth(String? token, String? groupId, Uri originalUri) {
    debugPrint('[DeepLinkService] Scheduling auth retry for token: $token');
    // Listen to auth state changes via a delayed check every 500ms (max 30s)
    var attempts = 0;
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      attempts++;
      if (attempts > 60) {
        // Give up after 30 seconds
        debugPrint('[DeepLinkService] Auth retry timed out after 30s.');
        timer.cancel();
        return;
      }

      final context = rootNavigatorKey.currentContext;
      if (context == null) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        timer.cancel();
        debugPrint('[DeepLinkService] Auth retry: user is now authenticated. Re-processing link.');
        // Reset dedup so the link can be processed
        _lastProcessedToken = null;
        _handleUri(originalUri);
      }
    });
  }

  /// Retry a Firestore operation if it fails due to a transient 'unavailable' error.
  Future<T> _retry<T>(Future<T> Function() operation, {int maxAttempts = 3}) async {
    int attempt = 0;
    int delayMs = 500;
    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;
        final errorStr = e.toString().toLowerCase();
        final isTransient = errorStr.contains('unavailable') || 
                            errorStr.contains('transient') ||
                            errorStr.contains('connection-failed');
        if (isTransient && attempt < maxAttempts) {
          debugPrint('[DeepLinkService] Firestore error: $e. Retrying attempt $attempt in ${delayMs}ms...');
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2; // exponential backoff
        } else {
          rethrow;
        }
      }
    }
  }

  // ── Navigation helpers ─────────────────────────────────────────────────────

  /// Resolve a token to a community or group and navigate/join accordingly.
  Future<void> _navigateToJoinFlow(String token) async {
    final communityRepo = CommunityRepositoryImpl();
    final inviteRepo = GroupInviteRepositoryImpl();
    final groupRepo = GroupRepositoryImpl();

    final navState = rootNavigatorKey.currentState;
    final context = rootNavigatorKey.currentContext;
    if (navState == null || context == null) {
      debugPrint('[DeepLinkService] Navigator not ready in _navigateToJoinFlow.');
      return;
    }

    try {
      // 1. Check if token is for a Community
      final community = await _retry(() => communityRepo.getCommunityByInviteLink(token));
      if (community != null) {
        final activeContext = rootNavigatorKey.currentContext;
        if (activeContext == null || !activeContext.mounted) return;
        final authProvider = Provider.of<AuthProvider>(activeContext, listen: false);
        final currentUserId = authProvider.currentUser?.uid;
        if (currentUserId == null) return;

        final member = await _retry(() => communityRepo.getMember(
          communityId: community.id,
          userId: currentUserId,
        ));

        if (member != null) {
          // Already a member, go straight to details
          navState.push(
            MaterialPageRoute(
              builder: (_) => CommunityDetailScreen(community: community),
            ),
          );
          _showSuccessSnackBar('أنت بالفعل عضو في هذا المجتمع!');
          return;
        }

        if (!community.isPublic) {
          // Closed community -> Request Screen
          navState.push(
            MaterialPageRoute(
              builder: (_) => CommunityJoinRequestScreen(
                community: community,
                token: token,
              ),
            ),
          );
          return;
        }

        // Open community -> Join immediately and go to details
        await _retry(() => communityRepo.joinCommunity(
          communityId: community.id,
          userId: currentUserId,
          userName: authProvider.currentUser?.name ?? 'User',
          userAvatarUrl: authProvider.currentUser?.avatarUrl,
        ));

        navState.push(
          MaterialPageRoute(
            builder: (_) => CommunityDetailScreen(community: community),
          ),
        );
        _showSuccessSnackBar('تم الانضمام إلى المجتمع بنجاح!');
        return;
      }

      // 2. Check if token is for a Group
      final invite = await _retry(() => inviteRepo.getInvite(token));
      GroupEntity? group;
      bool requiresApproval = false;

      if (invite != null) {
        if (!invite.isValid(DateTime.now())) {
          _showErrorSnackBar('رابط الدعوة هذا منتهي الصلاحية أو تم استخدامه بالكامل.');
          return;
        }
        group = await _retry(() => groupRepo.getGroup(invite.groupId));
        requiresApproval = invite.requiresApproval;
      } else {
        // Fallback to legacy UUID token lookup directly in group documents
        final legacyGroup = await _retry(() => groupRepo.getGroupByInviteLink(token));
        if (legacyGroup != null) {
          group = legacyGroup;
          requiresApproval = !legacyGroup.isPublic;
        }
      }

      if (group == null) {
        _showErrorSnackBar('رابط الدعوة هذا غير صالح أو قد تم حذفه.');
        return;
      }

      final activeContext = rootNavigatorKey.currentContext;
      if (activeContext == null || !activeContext.mounted) return;
      final authProvider = Provider.of<AuthProvider>(activeContext, listen: false);
      final currentUserId = authProvider.currentUser?.uid;
      if (currentUserId == null) return;

      if (group.isMember(currentUserId)) {
        // Already joined -> open chat
        navState.push(
          MaterialPageRoute(
            builder: (_) => GroupChatScreen(
              groupId: group!.id,
              currentUserId: currentUserId,
              currentUserName: authProvider.currentUser?.name ?? 'User',
              currentUserAvatarUrl: authProvider.currentUser?.avatarUrl,
            ),
          ),
        );
        _showSuccessSnackBar('أنت بالفعل عضو في هذه المجموعة!');
        return;
      }

      final approvalNeeded = requiresApproval || !group.isPublic;
      if (approvalNeeded) {
        // Closed group -> Request Screen
        navState.push(
          MaterialPageRoute(
            builder: (_) => JoinRequestScreen(token: token),
          ),
        );
        return;
      }

      // Open group -> Join immediately and open chat
      await _retry(() => groupRepo.joinViaInviteLink(
        groupId: group!.id,
        userId: currentUserId,
        userName: authProvider.currentUser?.name ?? 'User',
        userAvatarUrl: authProvider.currentUser?.avatarUrl,
      ));

      navState.push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(
            groupId: group!.id,
            currentUserId: currentUserId,
            currentUserName: authProvider.currentUser?.name ?? 'User',
            currentUserAvatarUrl: authProvider.currentUser?.avatarUrl,
          ),
        ),
      );
      _showSuccessSnackBar('تم الانضمام إلى المجموعة بنجاح!');
    } catch (e) {
      _showErrorSnackBar('حدث خطأ: $e');
      debugPrint('[DeepLinkService] Navigation error: $e');
    }
  }

  // ── Snack bar helpers ──────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
