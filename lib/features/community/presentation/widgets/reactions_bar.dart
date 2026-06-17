import 'package:flutter/material.dart';

/// Emoji reaction row that appears below a message on long-press.
class ReactionsBar extends StatelessWidget {
  final void Function(String emoji) onReact;
  final String? currentUserReaction;

  static const _emojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

  const ReactionsBar({
    super.key,
    required this.onReact,
    this.currentUserReaction,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ??
              Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _emojis.map((emoji) {
            final isSelected = currentUserReaction == emoji;
            return GestureDetector(
              onTap: () => onReact(emoji),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.2 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Compact reactions summary shown on a message bubble.
class ReactionsRow extends StatelessWidget {
  final Map<String, String> reactions; // Map<userId, emoji>
  final String currentUserId;
  final void Function(String emoji)? onTap;

  const ReactionsRow({
    super.key,
    required this.reactions,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    // Count per emoji
    final counts = <String, int>{};
    for (final emoji in reactions.values) {
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }

    final myReaction = reactions[currentUserId];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 2,
      runSpacing: 2,
      children: counts.entries.map((e) {
        final isMyReaction = myReaction == e.key;
        return GestureDetector(
          onTap: () => onTap?.call(e.key),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMyReaction
                  ? (isDark ? const Color(0xFF1E293B) : Colors.blue.shade50)
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isMyReaction
                    ? Colors.blue.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF0F172A) : Colors.white),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 12)),
                if (e.value > 1) ...[
                  const SizedBox(width: 3),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isMyReaction ? Colors.blue : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

