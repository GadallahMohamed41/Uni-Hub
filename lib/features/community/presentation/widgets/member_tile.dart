import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../domain/entities/group_member_entity.dart';

class MemberTile extends StatelessWidget {
  final GroupMemberEntity member;
  final bool canManage; // whether current user can promote/remove
  final VoidCallback? onRemove;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;

  const MemberTile({
    super.key,
    required this.member,
    this.canManage = false,
    this.onRemove,
    this.onPromote,
    this.onDemote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: _colorFor(member.name),
            child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: member.avatarUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  )
                : Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
          ),
          // Online indicator
          if (member.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _RoleBadge(role: member.role),
        ],
      ),
      subtitle: Text(
        member.isOnline
            ? 'Online'
            : member.lastSeen != null
                ? 'Last seen ${_formatLastSeen(member.lastSeen!)}'
                : 'Offline',
        style: TextStyle(
          fontSize: 12,
          color: member.isOnline
              ? AppTheme.success
              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      trailing: canManage && member.role != GroupRole.owner
          ? PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              onSelected: (val) {
                if (val == 'remove') onRemove?.call();
                if (val == 'promote') onPromote?.call();
                if (val == 'demote') onDemote?.call();
              },
              itemBuilder: (_) => [
                if (member.role == GroupRole.member)
                  const PopupMenuItem(
                    value: 'promote',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded,
                            color: AppTheme.primary),
                        SizedBox(width: 8),
                        Text('Make Admin'),
                      ],
                    ),
                  ),
                if (member.role == GroupRole.admin)
                  const PopupMenuItem(
                    value: 'demote',
                    child: Row(
                      children: [
                        Icon(Icons.person_rounded, color: AppTheme.warning),
                        SizedBox(width: 8),
                        Text('Remove Admin'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.person_remove_rounded, color: AppTheme.error),
                      SizedBox(width: 8),
                      Text('Remove from Group',
                          style: TextStyle(color: AppTheme.error)),
                    ],
                  ),
                ),
              ],
            )
          : null,
    );
  }

  static Color _colorFor(String name) {
    const colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      AppTheme.success,
      AppTheme.info,
    ];
    if (name.isEmpty) return AppTheme.primary;
    int hash = 0;
    for (final ch in name.codeUnits) {
      hash = (hash * 31 + ch) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }

  static String _formatLastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _RoleBadge extends StatelessWidget {
  final GroupRole role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    if (role == GroupRole.member) return const SizedBox.shrink();
    final isOwner = role == GroupRole.owner;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOwner
            ? AppTheme.warning.withValues(alpha: 0.15)
            : AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isOwner ? AppTheme.warning.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isOwner ? '👑 Owner' : '⭐ Admin',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isOwner ? AppTheme.warning : AppTheme.primary,
        ),
      ),
    );
  }
}

