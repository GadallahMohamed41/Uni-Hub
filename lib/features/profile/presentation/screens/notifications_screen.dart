import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // needed for Timestamp
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/features/home/presentation/screens/post_detail_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/lectures_section_screen.dart';
import 'package:project_test2/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/connections/data/repositories/connections_repository.dart';



class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _dismissedNotificationIds = {};
  final Set<String> _selectedNotificationIds = {};
  // Notifications accepted locally — shown as "Connected ✓" until dispose
  final Set<String> _acceptedNotificationIds = {};
  late Stream<List<Map<String, dynamic>>> _notificationsStream;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedNotificationIds.contains(id)) {
        _selectedNotificationIds.remove(id);
      } else {
        _selectedNotificationIds.add(id);
      }
    });
  }

  void _selectAll(List<Map<String, dynamic>> items) {
    setState(() {
      if (_selectedNotificationIds.length == items.length) {
        _selectedNotificationIds.clear();
      } else {
        _selectedNotificationIds.addAll(items.map((e) => (e['id'] as String?) ?? '').where((id) => id.isNotEmpty));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final idsToDelete = _selectedNotificationIds.toList();
    setState(() {
      _dismissedNotificationIds.addAll(idsToDelete);
      _selectedNotificationIds.clear();
    });
    final service = FirestoreService();
    for (final id in idsToDelete) {
      try {
        await service.deleteNotification(id);
      } catch (_) {}
    }
  }


  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthProvider>().userId;
    if (userId != null) {
      _notificationsStream = FirestoreService().getNotificationsStream(userId);
      Future.microtask(() async {
        await FirestoreService().markAllNotificationsRead(userId);
        try {
          await FirestoreService().cleanupPendingNotificationsForUser(userId);
        } catch (_) {}
      });
    } else {
      _notificationsStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    // Delete all locally-accepted connection-request notifications from Firestore
    // now that the user is leaving the screen.
    final service = FirestoreService();
    for (final id in _acceptedNotificationIds) {
      service.deleteNotification(id).catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_selectedNotificationIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleteSelected,
              tooltip: 'Delete Selected',
            ),
        ],
      ),
      body: userId == null
          ? const Center(child: Text('Sign in to view notifications'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _notificationsStream,
              builder: (context, snapshot) {
                final items = (snapshot.data ?? [])
                    .where((n) => !_dismissedNotificationIds.contains((n['id'] as String?) ?? ''))
                    .where((n) => !((n['type'] as String?) ?? '').contains('request'))
                    .toList();
                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      if (_selectedNotificationIds.isEmpty) return const SizedBox.shrink();
                      
                      final allSelected = _selectedNotificationIds.length == items.length && items.isNotEmpty;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: allSelected,
                              onChanged: (_) => _selectAll(items),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              activeColor: AppTheme.primary,
                            ),
                            Text(
                              'Select All',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            if (_selectedNotificationIds.isNotEmpty)
                              Text(
                                '${_selectedNotificationIds.length} selected',
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      );
                    }
                    final n = items[i - 1];
                    final id = (n['id'] as String?) ?? '';
                    return _NotificationItem(
                      notification: n,
                      isSelected: _selectedNotificationIds.contains(id),
                      isSelectionMode: _selectedNotificationIds.isNotEmpty,
                      isAccepted: _acceptedNotificationIds.contains(id),
                      onAccepted: (notifId) {
                        if (!mounted) return;
                        setState(() {
                          _acceptedNotificationIds.add(notifId);
                        });
                      },
                      onSelect: () => _toggleSelection(id),
                      onDismiss: (id) {
                        if (!mounted) return;
                        setState(() {
                          _dismissedNotificationIds.add(id);
                        });
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final void Function(String id) onDismiss;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onSelect;
  final bool isAccepted;
  final void Function(String notifId) onAccepted;

  const _NotificationItem({
    required this.notification,
    required this.onDismiss,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onSelect,
    this.isAccepted = false,
    required this.onAccepted,
  });

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();
    final fromUserId = notification['fromUserId'] as String? ?? '';
    final type = notification['type'] as String? ?? '';
    final postId = notification['postId'] as String? ?? '';
    final notificationId = notification['id'] as String? ?? '';
    final createdAt = (notification['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr = _formatTime(createdAt);

    if (postId.isNotEmpty && type == 'post_pending') {
      return FutureBuilder<String?>(
        future: service.getPostStatus(postId),
        builder: (context, snap) {
          final status = snap.data;
          var effectiveType = type;
          if (status == 'approved') {
            effectiveType = 'post_approved';
            if (notificationId.isNotEmpty) {
              final adminId = context.read<AuthProvider>().userId;
              Future.microtask(() => service.updateNotificationType(notificationId, 'post_approved', processedBy: adminId));
            }
          } else if (status == 'rejected') {
            effectiveType = 'post_rejected';
            if (notificationId.isNotEmpty) {
              final adminId = context.read<AuthProvider>().userId;
              Future.microtask(() => service.updateNotificationType(notificationId, 'post_rejected', processedBy: adminId));
            }
          }
          return _buildCard(context, service, fromUserId, effectiveType, postId, notificationId, timeStr);
        },
      );
    }

    return _buildCard(context, service, fromUserId, type, postId, notificationId, timeStr);
  }

  Widget _buildCard(
    BuildContext context,
    FirestoreService service,
    String fromUserId,
    String type,
    String postId,
    String notificationId,
    String timeStr,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FutureBuilder<UserModel?>(
      future: fromUserId.isNotEmpty
          ? service.getUser(fromUserId)
          : Future<UserModel?>.value(null),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final storedName = (notification['senderName'] as String?)?.trim();
        final storedAvatar = (notification['senderAvatarUrl'] as String?)?.trim();
        final userName = user?.name ?? (storedName?.isNotEmpty == true ? storedName! : 'Someone');
        final userAvatar = user?.avatarUrl ?? (storedAvatar?.isNotEmpty == true ? storedAvatar : null);
        final commentId = notification['commentId'] as String? ?? '';
        final parentCommentId = notification['parentCommentId'] as String? ?? '';
        final canOpenDetails =
            postId.isNotEmpty && type != 'post_pending' && type != 'post_approved' && type != 'post_rejected';

        String title = '';
        String subtitle = '';
        IconData icon = Icons.notifications;
        Color iconColor = AppTheme.primary;
        String badgeText = 'Update';

        switch (type) {
          case 'comment':
            title = 'commented on your post';
            subtitle = notification['text'] ?? '';
            icon = Icons.comment_rounded;
            iconColor = AppTheme.info;
            badgeText = 'Comment';
            break;
          case 'reply':
            title = 'replied to your comment';
            subtitle = notification['text'] ?? '';
            icon = Icons.reply_rounded;
            iconColor = AppTheme.info;
            badgeText = 'Reply';
            break;
          case 'like':
            title = 'liked your post';
            icon = Icons.thumb_up_rounded;
            iconColor = AppTheme.primary;
            badgeText = 'Like';
            break;
          case 'laugh':
            title = 'laughed at your post';
            icon = Icons.emoji_emotions_rounded;
            iconColor = AppTheme.warning;
            badgeText = 'React';
            break;
          case 'support':
            title = 'supported your post';
            icon = Icons.favorite_rounded;
            iconColor = AppTheme.error;
            badgeText = 'Support';
            break;
          case 'repost':
            title = 'reposted your post';
            subtitle = notification['text'] ?? '';
            icon = Icons.repeat_rounded;
            iconColor = AppTheme.success;
            badgeText = 'Repost';
            break;
          case 'comment_like':
            title = 'liked your comment';
            icon = Icons.thumb_up_rounded;
            iconColor = AppTheme.primary;
            badgeText = 'Like';
            break;
          case 'mention':
            title = 'mentioned you in a comment';
            subtitle = notification['text'] ?? '';
            icon = Icons.alternate_email_rounded;
            iconColor = AppTheme.info;
            badgeText = 'Mention';
            break;
          case 'post_pending':
            title = 'submitted a post for approval';
            subtitle = notification['text'] ?? '';
            icon = Icons.pending_actions_rounded;
            iconColor = AppTheme.primary;
            badgeText = 'Review';
            break;
          case 'post_approved':
            title = 'post approved';
            icon = Icons.check_circle_rounded;
            iconColor = AppTheme.success;
            badgeText = 'Approved';
            break;
          case 'post_rejected':
            title = 'post rejected';
            icon = Icons.cancel_rounded;
            iconColor = AppTheme.error;
            badgeText = 'Rejected';
            break;
          case 'schedule_uploaded':
            title = 'uploaded a lecture schedule';
            subtitle = 'Tap to view your schedule';
            icon = Icons.event_note_rounded;
            iconColor = AppTheme.success;
            badgeText = 'Schedule';
            break;
          case 'system_alert':
            title = 'System Alert';
            subtitle = notification['text'] ?? 'Important system update';
            icon = Icons.warning_rounded;
            iconColor = AppTheme.warning;
            badgeText = 'System Alert';
            break;
          case 'milestone':
            title = 'reached a new milestone';
            subtitle = notification['text'] ?? 'Congratulations on your achievement!';
            icon = Icons.emoji_events_rounded;
            iconColor = AppTheme.success;
            badgeText = 'Milestone';
            break;
          case 'connection_request':
            title = 'sent you a connection request';
            icon = Icons.person_add_rounded;
            iconColor = AppTheme.primary;
            badgeText = 'Connection';
            break;
          case 'request_accepted':
            title = 'accepted your connection request';
            icon = Icons.handshake_rounded;
            iconColor = AppTheme.success;
            badgeText = 'Connected';
            break;
          default:
            title = 'New activity';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 16, right: 8),
                  child: Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelect(),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    activeColor: AppTheme.primary,
                  ),
                ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected 
                          ? AppTheme.primary.withValues(alpha: 0.5) 
                          : iconColor.withValues(alpha: isDark ? 0.18 : 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onLongPress: onSelect,
              onTap: isSelectionMode
                  ? onSelect
                  : (type == 'schedule_uploaded'
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LecturesSectionScreen()),
                          )
                      : (canOpenDetails
                          ? () {
                              final targetCommentId = parentCommentId.trim().isNotEmpty
                                  ? parentCommentId.trim()
                                  : (commentId.trim().isNotEmpty ? commentId.trim() : null);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PostDetailScreen(
                                    postId: postId,
                                    initialCommentId: (type == 'comment' || type == 'reply' || type == 'comment_like' || type == 'mention')
                                        ? targetCommentId
                                        : null,
                                    parentCommentId: parentCommentId.trim().isNotEmpty ? parentCommentId.trim() : null,
                                    focusCommentInput: type == 'comment' || type == 'reply' || type == 'mention',
                                  ),
                                ),
                              );
                            }
                          : null)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (fromUserId.isNotEmpty && fromUserId != 'system') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserProfileScreen(userId: fromUserId),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: iconColor.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                                  backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                                      ? CachedNetworkImageProvider(userAvatar)
                                      : null,
                                  child: (userAvatar == null || userAvatar.isEmpty)
                                      ? Icon(Icons.person, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))
                                      : null,
                                ),
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: iconColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: theme.cardTheme.color ?? theme.colorScheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(icon, size: 12, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface, height: 1.35),
                                  children: [
                                    TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const TextSpan(text: ' '),
                                    TextSpan(text: title),
                                  ],
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    subtitle,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: iconColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      badgeText,
                                      style: TextStyle(
                                        color: iconColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(timeStr, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (canOpenDetails)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (type == 'connection_request') ...[
                      const SizedBox(height: 12),
                      if (isAccepted)
                        // ── Accepted state: shown until user leaves screen ──
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.success.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: AppTheme.success, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'You are now connected!',
                                style: TextStyle(
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final currentUserId =
                                      context.read<AuthProvider>().userId;
                                  if (currentUserId != null &&
                                      fromUserId.isNotEmpty) {
                                    await ConnectionsRepository(
                                            FirebaseFirestore.instance)
                                        .ignoreConnectionRequest(
                                      currentUserId: currentUserId,
                                      fromUserId: fromUserId,
                                    );
                                    if (notificationId.isNotEmpty) {
                                      await service
                                          .deleteNotification(notificationId);
                                    }
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  side: BorderSide(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.2)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  minimumSize: const Size(0, 42),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: const Text('Decline',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final currentUserId =
                                      context.read<AuthProvider>().userId;
                                  if (currentUserId != null &&
                                      fromUserId.isNotEmpty) {
                                    // Mark as accepted locally first (instant feedback)
                                    if (notificationId.isNotEmpty) {
                                      onAccepted(notificationId);
                                    }
                                    // Then call Firestore (no notification deletion)
                                    await ConnectionsRepository(
                                            FirebaseFirestore.instance)
                                        .acceptConnectionRequest(
                                      currentUserId: currentUserId,
                                      fromUserId: fromUserId,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  minimumSize: const Size(0, 42),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: const Text('Accept',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                    ] else if (type == 'post_pending' && postId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminDashboardScreen(initialTabIndex: 0),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Review', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                final adminId = context.read<AuthProvider>().userId;
                                await service.updatePostStatus(postId, 'rejected', adminId: adminId);
                                if (notificationId.isNotEmpty) {
                                  await service.updateNotificationType(notificationId, 'post_rejected', processedBy: adminId);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Reject', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final adminId = context.read<AuthProvider>().userId;
                                await service.updatePostStatus(postId, 'approved', adminId: adminId);
                                if (notificationId.isNotEmpty) {
                                  await service.updateNotificationType(notificationId, 'post_approved', processedBy: adminId);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: const Size(0, 42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Approve', style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}
