import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/core/theme/theme.dart';

/// Horizontal scrollable grid of community groups.
/// Each card shows the group name and lets users join/enter.
class CommunityGroupGrid extends StatelessWidget {
  final List<GroupEntity> groups;
  final String currentUserId;
  final void Function(GroupEntity group) onGroupTap;

  const CommunityGroupGrid({
    super.key,
    required this.groups,
    required this.currentUserId,
    required this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No groups yet',
            style: TextStyle(
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _GroupCard(
          group: groups[i],
          currentUserId: currentUserId,
          onTap: () => onGroupTap(groups[i]),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final GroupEntity group;
  final String currentUserId;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMember = group.isMember(currentUserId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Group avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isMember
                    ? AppTheme.primaryGradient
                    : const LinearGradient(
                        colors: [Color(0xFF94A3B8), Color(0xFF64748B)]),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: group.imageUrl != null && group.imageUrl!.isNotEmpty
                  ? ClipOval(
                      child: CachedNetworkImage(imageUrl: group.imageUrl!,
                          width: 48, height: 48, fit: BoxFit.cover))
                  : Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                group.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (!isMember) ...[
              const SizedBox(height: 4),
              Text(
                'Join',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

