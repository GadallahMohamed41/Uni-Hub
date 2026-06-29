import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/core/services/biometric_service.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _biometricEnabled = false;
  bool _loadingBiometric = true;

  @override
  void initState() {
    super.initState();
    _loadBiometricPref();
  }

  Future<void> _loadBiometricPref() async {
    final enabled = await BiometricService.instance.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _loadingBiometric = false;
      });
    }
  }

  // ─── Password Reset ──────────────────────────────────────────────────────
  Future<void> _sendResetLink(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = auth.currentUser?.email;

    if (email == null || email.isEmpty) {
      AppSnackBar.showError(context, 'No email address found');
      return;
    }

    final ok = await auth.resetPassword(email);
    if (!context.mounted) return;

    if (ok) {
      AppSnackBar.showSuccess(context, 'Password reset link sent to $email');
    } else {
      AppSnackBar.showError(context, auth.error ?? 'Failed to send reset link');
    }
  }

  // ─── Biometric Toggle ────────────────────────────────────────────────────
  Future<void> _onBiometricToggled(bool value) async {
    if (value) {
      final available = await BiometricService.instance.isAvailable();
      if (!mounted) return;

      if (!available) {
        AppSnackBar.showError(
          context,
          'Biometric authentication is not available on this device.',
        );
        return;
      }

      final success = await BiometricService.instance.authenticate(
        reason: 'Verify your fingerprint to enable biometric login',
      );
      if (!mounted) return;

      if (success) {
        await BiometricService.instance.setBiometricEnabled(true);
        if (!mounted) return;
        setState(() => _biometricEnabled = true);
        AppSnackBar.showSuccess(context, 'Biometric login enabled');
      } else {
        AppSnackBar.showError(
            context, 'Authentication failed. Biometric login not enabled.');
      }
    } else {
      await BiometricService.instance.setBiometricEnabled(false);
      if (!mounted) return;
      setState(() => _biometricEnabled = false);
      AppSnackBar.showSuccess(context, 'Biometric login disabled');
    }
  }

  // ─── Delete Account ──────────────────────────────────────────────────────
  void _showDeleteAccountDialog(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.cardTheme.color ?? theme.colorScheme.surface;
    final errorColor = theme.colorScheme.error;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: errorColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Icon(Icons.warning_amber_rounded,
                    color: errorColor, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Account',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This action is permanent and cannot be undone. All your data, posts, and connections will be lost forever.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppSnackBar.showError(
                            context, 'Account deletion coming soon.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: errorColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user =
        context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final isLoading =
        context.select<AuthProvider, bool>((auth) => auth.isLoading);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header (Compact, no animations) ─────────────────────────
          SliverToBoxAdapter(child: _buildHero(context)),

          // ── Cards (Compact) ──────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAccountCard(context, user),
                const SizedBox(height: 10),
                _buildPasswordCard(context, isLoading),
                const SizedBox(height: 10),
                _buildBiometricCard(context),
                const SizedBox(height: 10),
                _buildDangerZoneCard(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Back button + shield badge
              Row(
                children: [
                  _PillBackButton(
                    onTap: () => Navigator.pop(context),
                  ),
                  const Spacer(),
                  // Shield badge (tinted with primary app color)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified_user_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                'Privacy & Security',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981), // success green
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Your account is well protected',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, UserModel? user) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;
    
    final name = user?.name ?? 'User';
    final email = user?.email ?? '—';
    final initials =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';

    final avatarUrl = (user?.avatarUrl ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('ACCOUNT'),
          const SizedBox(height: 12),
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasAvatar ? Colors.transparent : primaryColor.withValues(alpha: 0.1),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  image: hasAvatar
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : Center(
                        child: Text(
                          initials,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Name + email
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: onSurfaceColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: TextStyle(
                        color: onSurfaceColor.withValues(alpha: 0.45),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Verified pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.25), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Verified',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded,
                  color: onSurfaceColor.withValues(alpha: 0.25), size: 20),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordCard(BuildContext context, bool isLoading) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('PASSWORD'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.lock_rounded,
                    color: primaryColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _RowTitle('Reset Password'),
                    const SizedBox(height: 3),
                    _RowSubtitle(
                        'Send a reset link to your registered email address.'),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: onSurfaceColor.withValues(alpha: 0.25), size: 20),
            ],
          ),
          const SizedBox(height: 12),
          // Send button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  isLoading ? null : () => _sendResetLink(context),
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 16, color: Colors.white),
              label: Text(
                isLoading ? 'Sending...' : 'Send password reset link',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final successColor = const Color(0xFF10B981);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionLabel('BIOMETRICS'),
          const SizedBox(height: 12),
          Row(
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fingerprint_rounded,
                    color: successColor, size: 22),
              ),
              const SizedBox(width: 12),
              // Labels
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RowTitle('Biometric Login'),
                    SizedBox(height: 3),
                    _RowSubtitle('Use fingerprint to unlock the app'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Toggle
              _loadingBiometric
                  ? SizedBox(
                      width: 36,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryColor),
                    )
                  : _CustomToggle(
                      value: _biometricEnabled,
                      onChanged: _onBiometricToggled,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return _Card(
      borderColor: errorColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Danger Zone label
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  color: errorColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'DANGER ZONE',
                style: TextStyle(
                  color: errorColor.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon box
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_remove_rounded,
                    color: errorColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: TextStyle(
                        color: errorColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Permanently delete your account and all associated data.',
                      style: TextStyle(
                        color: onSurfaceColor.withValues(alpha: 0.45),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Warning text
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: errorColor.withValues(alpha: 0.5),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Delete button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDeleteAccountDialog(context),
              icon: Icon(Icons.delete_outline_rounded,
                  color: errorColor, size: 16),
              label: Text(
                'Delete Account',
                style: TextStyle(
                    color: errorColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: errorColor.withValues(alpha: 0.4), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ──────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;

  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06)),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _RowTitle extends StatelessWidget {
  final String text;
  const _RowTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _RowSubtitle extends StatelessWidget {
  final String text;
  const _RowSubtitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
        fontSize: 12,
        height: 1.4,
      ),
    );
  }
}

class _PillBackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PillBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_ios_new_rounded,
                size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
            const SizedBox(width: 5),
            Text(
              'Back',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CustomToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? primaryColor
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          border: Border.all(
            color: value
                ? primaryColor.withValues(alpha: 0.6)
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(3),
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
