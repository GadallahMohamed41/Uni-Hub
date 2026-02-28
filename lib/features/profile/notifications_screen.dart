import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../home/post_detail_screen.dart';
import 'lectures_section_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _dismissedNotificationIds = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final userId = context.read<AuthProvider>().userId;
      if (userId == null) return;
      await FirestoreService().markAllNotificationsRead(userId);
      try {
        await FirestoreService().cleanupPendingNotificationsForUser(userId);
      } catch (_) {}
    });
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${time.day}/${time.month}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId;
    final service = FirestoreService();
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w700),
        ),
      ),
      body: userId == null
          ? const Center(child: Text('Sign in to view notifications'))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: service.getNotificationsStream(userId),
              builder: (context, snapshot) {
                final items = (snapshot.data ?? [])
                    .where((n) => !_dismissedNotificationIds.contains((n['id'] as String?) ?? ''))
                    .toList();
                if (items.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.textTertiary),
                        SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final n = items[i];
                    return _NotificationItem(
                      notification: n,
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

  const _NotificationItem({required this.notification, required this.onDismiss});

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
    return FutureBuilder<UserModel?>(
      future: fromUserId.isNotEmpty
          ? service.getUser(fromUserId)
          : Future<UserModel?>.value(null),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final userName = user?.name ?? 'Someone';
        final userAvatar = user?.avatarUrl;

        String title = '';
        String subtitle = '';
        IconData icon = Icons.notifications;
        Color iconColor = AppTheme.primary;

        switch (type) {
          case 'comment':
            title = 'commented on your post';
            subtitle = notification['text'] ?? '';
            icon = Icons.comment_rounded;
            iconColor = AppTheme.info;
            break;
          case 'reply':
            title = 'replied to your comment';
            subtitle = notification['text'] ?? '';
            icon = Icons.reply_rounded;
            iconColor = AppTheme.info;
            break;
          case 'like':
            title = 'liked your post';
            icon = Icons.thumb_up_rounded;
            iconColor = AppTheme.primary;
            break;
          case 'laugh':
            title = 'laughed at your post';
            icon = Icons.emoji_emotions_rounded;
            iconColor = AppTheme.accent;
            break;
          case 'support':
            title = 'supported your post';
            icon = Icons.favorite_rounded;
            iconColor = AppTheme.error;
            break;
          case 'repost':
            title = 'reposted your post';
            icon = Icons.repeat_rounded;
            iconColor = AppTheme.success;
            break;
          case 'post_pending':
            title = 'submitted a post for approval';
            subtitle = notification['text'] ?? '';
            icon = Icons.pending_actions_rounded;
            iconColor = AppTheme.primary;
            break;
          case 'post_approved':
            title = 'post approved';
            icon = Icons.check_circle_rounded;
            iconColor = AppTheme.success;
            break;
          case 'post_rejected':
            title = 'post rejected';
            icon = Icons.cancel_rounded;
            iconColor = AppTheme.error;
            break;
          case 'schedule_uploaded':
            title = 'uploaded a lecture schedule';
            subtitle = 'Tap to view your schedule';
            icon = Icons.event_note_rounded;
            iconColor = AppTheme.success;
            break;
          default:
            title = 'New activity';
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: type == 'schedule_uploaded'
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LecturesSectionScreen()),
                      )
                  : (postId.isNotEmpty && type != 'post_pending' && type != 'post_approved' && type != 'post_rejected'
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: postId)),
                          )
                      : null),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.surfaceVariant,
                              backgroundImage: (userAvatar != null && userAvatar.isNotEmpty)
                                  ? CachedNetworkImageProvider(userAvatar)
                                  : null,
                              child: (userAvatar == null || userAvatar.isEmpty)
                                  ? const Icon(Icons.person, color: AppTheme.textTertiary)
                                  : null,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.surface, width: 2),
                                ),
                                child: Icon(icon, size: 12, color: iconColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(fontSize: 15, color: AppTheme.textMain, height: 1.35),
                                  children: [
                                    TextSpan(text: userName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    const TextSpan(text: ' '),
                                    TextSpan(text: title),
                                  ],
                                ),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: AppTheme.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Text(timeStr, style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
                            ],
                          ),
                        ),
                        if (postId.isNotEmpty && type != 'post_pending')
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
                          ),
                      ],
                    ),
                    if (type == 'post_pending' && postId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await service.deletePostDeep(postId);
                                if (notificationId.isNotEmpty) {
                                  final adminId = context.read<AuthProvider>().userId;
                                  await service.updateNotificationType(notificationId, 'post_rejected', processedBy: adminId);
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                side: const BorderSide(color: AppTheme.error),
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Reject'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await service.updatePostStatus(postId, 'approved');
                                if (notificationId.isNotEmpty) {
                                  final adminId = context.read<AuthProvider>().userId;
                                  await service.updateNotificationType(notificationId, 'post_approved', processedBy: adminId);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.success,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(42),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              child: const Text('Approve'),
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
