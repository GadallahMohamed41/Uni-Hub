import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class MuteBottomSheet extends StatelessWidget {
  final bool isCurrentlyMuted;
  final void Function(DateTime? muteUntil) onMuteSelected;

  const MuteBottomSheet({
    super.key,
    required this.isCurrentlyMuted,
    required this.onMuteSelected,
  });

  static void show(
    BuildContext context, {
    required bool isCurrentlyMuted,
    required void Function(DateTime? muteUntil) onMuteSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MuteBottomSheet(
        isCurrentlyMuted: isCurrentlyMuted,
        onMuteSelected: (val) {
          Navigator.pop(context);
          onMuteSelected(val);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Mute Notifications',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: divColor),
            if (isCurrentlyMuted) ...[
              _MuteOption(
                icon: Icons.notifications_active_rounded,
                label: 'Unmute',
                iconColor: AppTheme.primary,
                onTap: () => onMuteSelected(null),
              ),
              Divider(height: 1, color: divColor),
            ],
            _MuteOption(
              icon: Icons.access_time_rounded,
              label: '8 Hours',
              iconColor: Colors.grey.shade500,
              onTap: () =>
                  onMuteSelected(DateTime.now().add(const Duration(hours: 8))),
            ),
            Divider(height: 1, color: divColor),
            _MuteOption(
              icon: Icons.calendar_today_rounded,
              label: '1 Week',
              iconColor: Colors.grey.shade500,
              onTap: () =>
                  onMuteSelected(DateTime.now().add(const Duration(days: 7))),
            ),
            Divider(height: 1, color: divColor),
            _MuteOption(
              icon: Icons.all_inclusive_rounded,
              label: 'Always',
              iconColor: Colors.grey.shade500,
              isLast: true,
              // For "Always", we add 100 years.
              onTap: () =>
                  onMuteSelected(DateTime.now().add(const Duration(days: 36500))),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuteOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;
  final bool isLast;

  const _MuteOption({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(24))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
