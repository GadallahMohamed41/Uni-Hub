import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/community_entity.dart';
import '../../../../core/theme.dart';

/// Premium WhatsApp-style Community list tile.
class CommunityTile extends StatelessWidget {
  final CommunityEntity community;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CommunityTile({
    super.key,
    required this.community,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      splashColor: AppTheme.primary.withValues(alpha: 0.06),
      highlightColor: AppTheme.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // ── Large rounded avatar ─────────────────────────────────────
            _CommunityAvatar(
              imageUrl: community.imageUrl,
              name: community.name,
              size: 62,
            ),
            const SizedBox(width: 14),

            // ── Info ─────────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badge row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          community.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _VisibilityBadge(isPublic: community.isPublic),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Description or "No description"
                  Text(
                    community.description.isNotEmpty
                        ? community.description
                        : 'No description',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Chevron ───────────────────────────────────────────────────
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────

class _CommunityAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  const _CommunityAvatar({
    required this.imageUrl,
    required this.name,
    this.size = 62,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Fallback(name: name, size: size),
          errorWidget: (_, __, ___) => _Fallback(name: name, size: size),
        ),
      );
    }
    return _Fallback(name: name, size: size);
  }
}

class _Fallback extends StatelessWidget {
  final String name;
  final double size;
  const _Fallback({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'C',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

// ── Public / Private badge ─────────────────────────────────────────────────────

class _VisibilityBadge extends StatelessWidget {
  final bool isPublic;
  const _VisibilityBadge({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    final color = isPublic ? AppTheme.success : AppTheme.warning;
    final icon = isPublic ? Icons.public_rounded : Icons.lock_rounded;
    final label = isPublic ? 'Public' : 'Private';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

