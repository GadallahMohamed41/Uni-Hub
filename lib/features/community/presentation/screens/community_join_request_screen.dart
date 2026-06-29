import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';
import 'package:project_test2/features/community/data/repositories/community_repository_impl.dart';

class CommunityJoinRequestScreen extends StatefulWidget {
  final CommunityEntity community;
  final String token;

  const CommunityJoinRequestScreen({
    super.key,
    required this.community,
    required this.token,
  });

  @override
  State<CommunityJoinRequestScreen> createState() => _CommunityJoinRequestScreenState();
}

class _CommunityJoinRequestScreenState extends State<CommunityJoinRequestScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  int _memberCount = 0;
  bool _loadingCount = true;

  // Animation controllers
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;
  late final List<AnimationController> _cardCtrls;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _fetchMemberCount();

    // Floating avatar animation
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6.0, end: 0.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    // Staggered card animation
    const delays = [0, 80, 160, 240];
    _cardCtrls = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _cardFades = _cardCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut) as Animation<double>)
        .toList();
    _cardSlides = _cardCtrls
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)))
        .toList();

    for (var i = 0; i < _cardCtrls.length; i++) {
      Future.delayed(Duration(milliseconds: delays[i]), () {
        if (mounted) _cardCtrls[i].forward();
      });
    }

    // Shimmer effect animation
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
  }

  Future<void> _fetchMemberCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.community.id)
          .collection('members')
          .count()
          .get();
      if (mounted) {
        setState(() {
          _memberCount = snap.count ?? 0;
          _loadingCount = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCount = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    for (final c in _cardCtrls) {
      c.dispose();
    }
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitJoinRequest() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      AppSnackBar.showError(context, 'يجب تسجيل الدخول أولاً.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = CommunityRepositoryImpl();
      await repo.requestToJoinCommunity(
        communityId: widget.community.id,
        userId: auth.userId!,
        userName: auth.currentUser?.name ?? 'Unknown User',
        userAvatarUrl: auth.currentUser?.avatarUrl,
      );

      if (!mounted) return;
      AppSnackBar.showSuccess(
        context,
        Localizations.localeOf(context).languageCode == 'ar'
            ? 'تم إرسال طلب الانضمام بنجاح! بانتظار موافقة المسؤول.'
            : 'Join request submitted successfully! Awaiting admin approval.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = theme.brightness == Brightness.dark;
    final firstLetter = widget.community.name.isNotEmpty
        ? widget.community.name[0].toUpperCase()
        : 'C';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Hero Header
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        height: 260,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                : [AppTheme.primary, AppTheme.primaryDark],
                          ),
                        ),
                        child: SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _HeroCircleButton(
                                  icon: Icons.chevron_left,
                                  onTap: () => Navigator.of(context).pop(),
                                ),
                                Text(
                                  isArabic ? 'الانضمام للمجتمع' : 'JOIN COMMUNITY',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 38), // placeholder spacer
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Floating community avatar
                      Positioned(
                        bottom: -44,
                        child: AnimatedBuilder(
                          animation: _floatAnim,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _floatAnim.value),
                            child: child,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFAFA9EC),
                                      Color(0xFF7F77DD),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.30),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: widget.community.imageUrl != null &&
                                        widget.community.imageUrl!.isNotEmpty
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: widget.community.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _avatarFallback(firstLetter),
                                        ),
                                      )
                                    : _avatarFallback(firstLetter),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 58),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          widget.community.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.community.description.isNotEmpty
                              ? widget.community.description
                              : (isArabic
                                  ? 'لا يوجد وصف متاح لهذا المجتمع.'
                                  : 'No description available for this community.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.60),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Members pill
                        if (!_loadingCount)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.group,
                                    size: 14, color: AppTheme.primary),
                                const SizedBox(width: 5),
                                Text(
                                  isArabic
                                      ? '$_memberCount ${_memberCount == 1 ? 'عضو' : 'أعضاء'}'
                                      : '$_memberCount ${_memberCount == 1 ? 'member' : 'members'}',
                                  style: const TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // Cards Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Card 1: Tags
                        _staggered(
                          0,
                          _TagsCard(
                            isPublic: widget.community.isPublic,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card 2: Info details
                        _staggered(
                          1,
                          _InfoCard(
                            memberCount: _memberCount,
                            loadingCount: _loadingCount,
                            isArabic: isArabic,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Card 3: About
                        _staggered(
                          2,
                          _AboutCard(
                            isArabic: isArabic,
                            description: widget.community.description.isNotEmpty
                                ? widget.community.description
                                : (isArabic
                                    ? 'لا يوجد وصف متاح.'
                                    : 'No description provided.'),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Card 4: Action Buttons
                        _staggered(
                          3,
                          Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: _CopyLinkButton(token: widget.token),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: _ShimmerJoinButton(
                                  shimmerAnim: _shimmerAnim,
                                  isArabic: isArabic,
                                  onPressed: _submitJoinRequest,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _staggered(int i, Widget child) => FadeTransition(
        opacity: _cardFades[i],
        child: SlideTransition(position: _cardSlides[i], child: child),
      );

  Widget _avatarFallback(String letter) => Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

class _HeroCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.30),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const _BaseCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TagsCard extends StatelessWidget {
  final bool isPublic;
  const _TagsCard({required this.isPublic});

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return _BaseCard(
      child: Wrap(
        spacing: 10,
        children: [
          _TagChip(
            icon: isPublic ? Icons.public : Icons.lock,
            label: isPublic
                ? (isArabic ? 'عام' : 'Public')
                : (isArabic ? 'خاص' : 'Private'),
            bg: const Color(0xFFEEEDFE),
            fg: const Color(0xFF3C3489),
          ),
          _TagChip(
            icon: Icons.verified_user,
            label: isArabic ? 'يتطلب موافقة' : 'Requires Approval',
            bg: const Color(0xFFE6F1FB),
            fg: const Color(0xFF0C447C),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg, fg;
  const _TagChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final int memberCount;
  final bool loadingCount;
  final bool isArabic;
  const _InfoCard({
    required this.memberCount,
    required this.loadingCount,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return _BaseCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const _LeadingBox(
                  bg: Color(0xFFEEEDFE),
                  icon: Icons.group,
                  color: Color(0xFF534AB7),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'الأعضاء' : 'Members',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        loadingCount
                            ? '...'
                            : (isArabic
                                ? '$memberCount ${memberCount == 1 ? 'عضو' : 'أعضاء'}'
                                : '$memberCount ${memberCount == 1 ? 'member' : 'members'}'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isArabic ? 'نشط' : 'Active',
                    style: const TextStyle(
                        color: Color(0xFF3B6D11),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              thickness: 0.5,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              indent: 16,
              endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const _LeadingBox(
                  bg: Color(0xFFE6F1FB),
                  icon: Icons.access_time,
                  color: Color(0xFF0C447C),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'وقت المراجعة' : 'Review time',
                        style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic ? '~24 ساعة' : '~24 hours',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                    ],
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

class _LeadingBox extends StatelessWidget {
  final Color bg, color;
  final IconData icon;
  const _LeadingBox({
    required this.bg,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, size: 17, color: color),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final String description;
  final bool isArabic;
  const _AboutCard({required this.description, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF334155).withValues(alpha: 0.3), const Color(0xFF1E293B).withValues(alpha: 0.3)]
              : [const Color(0xFFEEEDFE), const Color(0xFFE6F1FB)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7F77DD).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isArabic ? 'حول هذا المجتمع' : 'ABOUT THIS COMMUNITY',
            style: const TextStyle(
              color: Color(0xFF534AB7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyLinkButton extends StatelessWidget {
  final String token;
  const _CopyLinkButton({required this.token});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(
          text:
              'https://university-connect-52779.web.app/community/invite?token=$token',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تم نسخ رابط الدعوة!'
                  : 'Invite link copied!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.copy_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'نسخ الرابط'
                  : 'Copy Link',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerJoinButton extends StatelessWidget {
  final Animation<double> shimmerAnim;
  final bool isArabic;
  final VoidCallback onPressed;

  const _ShimmerJoinButton({
    required this.shimmerAnim,
    required this.isArabic,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: AppTheme.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer Overlay
                AnimatedBuilder(
                  animation: shimmerAnim,
                  builder: (context, _) => Positioned.fill(
                    child: FractionalTranslation(
                      translation: Offset(shimmerAnim.value, 0.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Text(
                  isArabic ? 'إرسال طلب انضمام' : 'Send Join Request',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
