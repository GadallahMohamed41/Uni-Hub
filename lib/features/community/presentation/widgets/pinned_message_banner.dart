import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../domain/entities/group_message_entity.dart';

class PinnedMessageBanner extends StatelessWidget {
  final GroupMessageEntity message;
  final bool canDismiss;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const PinnedMessageBanner({
    super.key,
    required this.message,
    this.canDismiss = false,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.push_pin_rounded,
              color: AppTheme.primary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pinned Message',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.deletedForAll
                        ? 'This message was deleted'
                        : message.text.isNotEmpty
                            ? message.text
                            : message.mediaUrls.isNotEmpty
                                ? '📎 Media'
                                : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (canDismiss)
              GestureDetector(
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppTheme.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

