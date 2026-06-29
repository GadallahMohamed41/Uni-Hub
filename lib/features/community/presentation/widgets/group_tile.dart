import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/group_avatar.dart';

/// WhatsApp-style group list tile with unread accent bar and gradient badge.
class GroupTile extends StatelessWidget {
  final GroupEntity group;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GroupTile({
    super.key,
    required this.group,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = group.myUnread(currentUserId);
    final hasUnread = unread > 0;
    final lastAt = group.lastMessageAt;
    final timeStr = lastAt != null ? _formatTime(lastAt) : '';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: AppTheme.primary.withValues(alpha: 0.06),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          // Subtle left accent when there are unread messages
          border: hasUnread
              ? Border(
                  left: BorderSide(
                    color: AppTheme.primary,
                    width: 3,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────────────────
            GroupAvatar(
              imageUrl: group.imageUrl,
              groupName: group.name,
              radius: 28,
            ),
            const SizedBox(width: 14),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + Time row
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (group.isAnnouncementOnly) ...[
                              Icon(
                                Icons.campaign_rounded,
                                size: 15,
                                color: AppTheme.primary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Flexible(
                              child: Text(
                                group.name,
                                style: TextStyle(
                                  fontWeight: hasUnread
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 15.5,
                                  color: theme.colorScheme.onSurface,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: hasUnread
                              ? AppTheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          fontWeight: hasUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message + unread badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.lastMessage.isNotEmpty
                              ? group.lastMessage
                              : 'No messages yet',
                          style: TextStyle(
                            fontSize: 13,
                            color: hasUnread
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.82)
                                : theme.colorScheme.onSurface.withValues(alpha: 0.50),
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        _UnreadBadge(count: unread),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }
}

// ── Unread Badge ──────────────────────────────────────────────────────────────

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

