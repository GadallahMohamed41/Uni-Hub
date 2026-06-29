import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
<<<<<<< HEAD
import 'package:project_test2/core/config/app_config.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/action_icon_button.dart';
import 'package:project_test2/features/community/presentation/widgets/invite_qr_bottom_sheet.dart';
=======
import '../../../../core/app_config.dart';
import '../../../../core/app_snackbar.dart';
import '../../domain/entities/group_entity.dart';
import 'action_icon_button.dart';
import 'invite_qr_bottom_sheet.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

/// Displays the invite link row with copy and QR code action buttons.
/// Follows clean architecture — purely presentational, stateless widget.
///
/// Usage:
/// ```dart
/// GroupInviteSection(group: state.group)
/// ```
class GroupInviteSection extends StatelessWidget {
  final GroupEntity group;

  const GroupInviteSection({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final token = group.inviteLink ?? '';

    if (token.isEmpty) return const SizedBox.shrink();

    // Build full HTTPS deep link URL so phone camera shows a clickable "Open" button
    final inviteLink = token.startsWith('http')
        ? token
        : '${AppConfig.deepLinkDomain}/group/invite?token=$token';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Link icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.link_rounded, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),

          // Invite link text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite link',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  inviteLink,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.8),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Copy button
          ActionIconButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copy link',
            semanticsLabel: 'Copy invite link',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: inviteLink));
              AppSnackBar.showSuccess(context, 'Invite link copied!');
            },
          ),
          const SizedBox(width: 8),

          // QR button
          ActionIconButton(
            icon: Icons.qr_code_rounded,
            tooltip: 'Show QR code',
            semanticsLabel: 'Show group QR code',
            onPressed: () => InviteQrBottomSheet.show(
              context,
              inviteLink: inviteLink,
              group: group,
            ),
          ),
        ],
      ),
    );
  }
}

