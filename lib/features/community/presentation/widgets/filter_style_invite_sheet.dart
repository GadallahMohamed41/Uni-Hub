import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:project_test2/core/services/deep_link_service.dart';

/// A premium bottom sheet styled after the system QR scanner "filter_app_links" UX.
/// Shows group invite details with "Copy link" and "Join group" actions.
/// The invite URL is NEVER shown in the UI.
class FilterStyleInviteSheet extends StatefulWidget {
  final String groupName;
  final String groupDescription;
  final String inviteUrl;

  const FilterStyleInviteSheet({
    super.key,
    required this.groupName,
    required this.groupDescription,
    required this.inviteUrl,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupName,
    required String groupDescription,
    required String inviteUrl,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => FilterStyleInviteSheet(
        groupName: groupName,
        groupDescription: groupDescription,
        inviteUrl: inviteUrl,
      ),
    );
  }

  @override
  State<FilterStyleInviteSheet> createState() => _FilterStyleInviteSheetState();
}

class _FilterStyleInviteSheetState extends State<FilterStyleInviteSheet>
    with SingleTickerProviderStateMixin {
  // ── Design tokens ────────────────────────────────────────────────────────
  static const _bg       = Color(0xFF111318);
  static const _card     = Color(0xFF1C2033);
  static const _accent   = Color(0xFF4F8EF7);
  static const _copyBtn  = Color(0xFF252D4A);
  static const _textMuted = Color(0xFF7A85A3);
  static const _textLight = Color(0xFFCDD5F3);
  static const _divider  = Color(0xFF242B47);

  late AnimationController _sheetCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideIn;

  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _sheetCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fadeIn = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutCubic));

    _sheetCtrl.forward();
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  void _copyLink() {
    Clipboard.setData(ClipboardData(text: widget.inviteUrl));
    setState(() => _copied = true);

    // Show toast
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        backgroundColor: const Color(0xFF0D2518),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 2),
        elevation: 0,
        content: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xFF1A7A44),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            const Text(
              'Link copied!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );

    // Reset icon after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _joinGroup() async {
    final uri = Uri.tryParse(widget.inviteUrl);
    if (uri == null) return;

    final token = uri.queryParameters['token'];
    if (token != null && token.isNotEmpty) {
      if (mounted) Navigator.of(context).pop();
      DeepLinkService.instance.processToken(token);
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: _buildSheet(),
      ),
    );
  }

  Widget _buildSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF343A56),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────────
          _buildTopBar(),

          const SizedBox(height: 14),

          // ── Invite card ──────────────────────────────────────────────────
          _buildInviteCard(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App logo — blue rounded square with filter icon
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF5B9BFF), Color(0xFF3A72E8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
        ),

        const SizedBox(width: 12),

        // App label + name
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'App',
              style: TextStyle(
                color: _textMuted.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 1),
            const Text(
              'NATU-Students',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Chat bubble icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: _textMuted,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _buildInviteCard() {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF2A3155),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Group avatar icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.group_rounded, color: _accent, size: 26),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.groupDescription,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            child: Divider(color: _divider, thickness: 1, height: 0),
          ),

          // ── Description ──────────────────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              "You've been invited to join this private group. Tap below to copy the invite link or join directly.",
              style: TextStyle(
                color: _textLight,
                fontSize: 13.5,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Action buttons ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                // Copy link button
                Expanded(
                  child: _PillButton(
                    label: _copied ? 'Copied!' : 'Copy link',
                    icon: _copied
                        ? Icons.check_rounded
                        : Icons.copy_rounded,
                    backgroundColor: _copied
                        ? const Color(0xFF1A3A28)
                        : _copyBtn,
                    foregroundColor: _copied
                        ? const Color(0xFF4CAF6F)
                        : _textMuted,
                    onTap: _copyLink,
                  ),
                ),
                const SizedBox(width: 10),
                // Join group button
                Expanded(
                  child: _PillButton(
                    label: 'Join group',
                    icon: Icons.group_add_rounded,
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    onTap: _joinGroup,
                    isAccent: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill button with press animation ─────────────────────────────────────────

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final bool isAccent;

  const _PillButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) => _ctrl.forward();
  void _onTapUp(TapUpDetails _) async {
    await Future.delayed(const Duration(milliseconds: 70));
    if (mounted) _ctrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(50),
            boxShadow: widget.isAccent
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F8EF7).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.foregroundColor, size: 16),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.foregroundColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
