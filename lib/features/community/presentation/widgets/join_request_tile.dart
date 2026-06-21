import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/join_request_entity.dart';
import '../../../../core/theme.dart';

/// Tile for a single join request shown in the Admin Panel.
class JoinRequestTile extends StatelessWidget {
  final JoinRequestEntity request;
  final VoidCallback onApprove;
  final VoidCallback onDeny;

  const JoinRequestTile({
    super.key,
    required this.request,
    required this.onApprove,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            backgroundImage: request.userAvatarUrl != null
                ? CachedNetworkImageProvider(request.userAvatarUrl!)
                : null,
            child: request.userAvatarUrl == null
                ? Text(
                    request.userName.isNotEmpty
                        ? request.userName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.userName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(request.requestedAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Deny button
          IconButton(
            onPressed: onDeny,
            icon: const Icon(Icons.close_rounded),
            color: AppTheme.error,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.error.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
            ),
          ),
          const SizedBox(width: 8),

          // Approve button
          IconButton(
            onPressed: onApprove,
            icon: const Icon(Icons.check_rounded),
            color: AppTheme.success,
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.success.withValues(alpha: 0.1),
              padding: const EdgeInsets.all(8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

