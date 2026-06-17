import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/group_invite/group_invite_cubit.dart';
import '../bloc/group_invite/group_invite_state.dart';
import '../../data/repositories/group_invite_repository_impl.dart';
import '../../domain/entities/group_entity.dart';

/// A premium, theme-aware QR code bottom sheet.
/// Shows only Copy Link and Join Group actions.
class InviteQrBottomSheet extends StatefulWidget {
  final String inviteLink;
  final GroupEntity group;

  const InviteQrBottomSheet({
    super.key,
    required this.inviteLink,
    required this.group,
  });

  static void show(
    BuildContext context, {
    required String inviteLink,
    required GroupEntity group,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider(
        create: (context) => GroupInviteCubit(
          repository: GroupInviteRepositoryImpl(firestore: FirebaseFirestore.instance),
        ),
        child: InviteQrBottomSheet(
          inviteLink: inviteLink,
          group: group,
        ),
      ),
    );
  }

  @override
  State<InviteQrBottomSheet> createState() => _InviteQrBottomSheetState();
}

class _InviteQrBottomSheetState extends State<InviteQrBottomSheet> {
  final ScreenshotController _screenshotController = ScreenshotController();

  String? _extractToken(String url) {
    try {
      return Uri.parse(url).queryParameters['token'];
    } catch (_) {
      return null;
    }
  }

  /// Build full HTTPS link with group metadata encoded in query params.
  /// This is what goes into the QR — it lands on the web page showing
  /// group info + "Copy Link" and "Join Group" buttons.
  String _buildQrLink() {
    final token = _extractToken(widget.inviteLink) ?? '';
    final uri = Uri.parse(widget.inviteLink);
    final host = uri.host.isNotEmpty ? uri.host : 'university-connect-52779.web.app';
    final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'https';
    return Uri(
      scheme: scheme,
      host: host,
      path: '/group/invite',
      queryParameters: {
        'token': token,
        'name': widget.group.name,
        if (widget.group.description.isNotEmpty) 'desc': widget.group.description,
        if (widget.group.imageUrl != null && widget.group.imageUrl!.isNotEmpty)
          'avatar': widget.group.imageUrl!,
      },
    ).toString();
  }

  void _onCopyLink(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('تم نسخ الرابط!'),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onSaveQr(BuildContext context) async {
    try {
      final bytes = await _screenshotController.capture(
        delay: const Duration(milliseconds: 150),
      );
      if (bytes != null && context.mounted) {
        context.read<GroupInviteCubit>().downloadQrCode(bytes, name: widget.group.name);
      }
    } catch (e) {
      if (context.mounted) {
        _showErrorDialog(context, 'خطأ في حفظ الـ QR: $e');
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: cs.surface,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                ),
                const SizedBox(height: 20),
                Text('خطأ',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 8),
                Text(message,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text('موافق'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final qrSize = MediaQuery.sizeOf(context).width * 0.55;
    final qrLink = _buildQrLink();

    return BlocListener<GroupInviteCubit, GroupInviteState>(
      listener: (context, state) {
        if (state is GroupInviteActionSuccess) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(state.successMessage),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        } else if (state is GroupInviteActionError) {
          _showErrorDialog(context, state.errorMessage);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),

            // Group name & subtitle
            Text(
              widget.group.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'امسح الكود للانضمام إلى المجموعة',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 28),

            // QR Code card
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: qrSize + 48,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      label: 'QR code for joining ${widget.group.name}',
                      child: QrImageView(
                        data: qrLink,
                        version: QrVersions.auto,
                        size: qrSize,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: cs.onSurface,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: cs.onSurface,
                        ),
                        backgroundColor: cs.surfaceContainerHighest,
                        errorCorrectionLevel: QrErrorCorrectLevel.H,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.group.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Primary Action: Copy Link ──────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _onCopyLink(context, qrLink),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('نسخ الرابط'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Secondary Action: Save QR ───────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _onSaveQr(context),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('حفظ صورة QR'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: cs.onSurfaceVariant,
                  side: BorderSide(color: cs.outline.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
