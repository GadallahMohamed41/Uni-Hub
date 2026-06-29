import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/data/repositories/group_invite_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_join_request_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/presentation/bloc/group_join_request/group_join_request_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/group_join_request/group_join_request_event.dart';
import 'package:project_test2/features/community/presentation/bloc/group_join_request/group_join_request_state.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kPrimary      = Color(0xFF534AB7);
const _kPrimaryDark  = Color(0xFF26215C);
const _kPrimaryLight = Color(0xFF8B83E6);
const _kTagPurpleBg  = Color(0xFFEEEDFE);
const _kTagPurpleFg  = Color(0xFF3C3489);
const _kTagBlueBg    = Color(0xFFE6F1FB);
const _kTagBlueFg    = Color(0xFF0C447C);
const _kActiveBg     = Color(0xFFEAF3DE);
const _kActiveFg     = Color(0xFF3B6D11);
const _kOnline       = Color(0xFF3DD68C);

// ─────────────────────────────────────────────────────────────────────────────
// Main screen — StatefulWidget owning all AnimationControllers
// ─────────────────────────────────────────────────────────────────────────────

class JoinRequestScreen extends StatefulWidget {
  final String token;
  const JoinRequestScreen({super.key, required this.token});

  @override
  State<JoinRequestScreen> createState() => _JoinRequestScreenState();
}

class _JoinRequestScreenState extends State<JoinRequestScreen>
    with TickerProviderStateMixin {

  // ── Avatar float ─────────────────────────────────────────────────────────
  late final AnimationController _floatCtrl;
  late final Animation<double> _floatAnim;

  // ── Cards stagger (4 cards) ───────────────────────────────────────────────
  late final List<AnimationController> _cardCtrls;
  late final List<Animation<double>> _cardFades;
  late final List<Animation<Offset>> _cardSlides;

  // ── Shimmer button ────────────────────────────────────────────────────────
  late final AnimationController _shimmerCtrl;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();

    // Float — 4s ease-in-out loop
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _floatAnim = Tween<double>(begin: -6.0, end: 0.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );
    _floatCtrl.repeat(reverse: true);

    // Stagger — 4 cards, 80ms apart
    const delays = [0, 80, 160, 240];
    _cardCtrls = List.generate(
      4,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _cardFades = _cardCtrls
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeOut)
            as Animation<double>)
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

    // Shimmer — 2.5s repeat
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear),
    );
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GroupJoinRequestBloc(
        inviteRepository: GroupInviteRepositoryImpl(
            firestore: FirebaseFirestore.instance),
        joinRequestRepository: GroupJoinRequestRepositoryImpl(
            firestore: FirebaseFirestore.instance),
        groupRepository: GroupRepositoryImpl(
            firestore: FirebaseFirestore.instance),
      )..add(LoadJoinRequestByToken(widget.token)),
      child: BlocConsumer<GroupJoinRequestBloc, GroupJoinRequestState>(
        listener: (context, state) {
          if (state is GroupJoinRequestSubmitted) {
            final isDirectJoin = state.request.requestId == 'direct_join';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(isDirectJoin
                    ? 'تم الانضمام إلى المجموعة بنجاح!'
                    : 'تم إرسال طلب الانضمام بنجاح! بانتظار موافقة المسؤول.'),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.of(context).pop();
          } else if (state is GroupJoinRequestError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          // ── Loading ──────────────────────────────────────────────────────
          if (state is GroupJoinRequestInitial ||
              state is GroupJoinRequestLoading) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(color: _kPrimary),
              ),
            );
          }

          // ── Error ────────────────────────────────────────────────────────
          if (state is GroupJoinRequestError) {
            return _ErrorScreen(message: state.message);
          }

          // ── Loaded ───────────────────────────────────────────────────────
          if (state is GroupJoinRequestTokenLoaded) {
            final group = state.group;
            final invite = state.invite;
            final requiresApproval =
                invite.requiresApproval || !group.isPublic;
            final memberCount = group.memberIds.length;
            final firstLetter =
                group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G';

            return Scaffold(
              backgroundColor: Colors.white,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ────────────────────────────────────────────────────
                    // Hero section (Stack: banner + floating avatar)
                    // ────────────────────────────────────────────────────
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Gradient banner
                        Container(
                          height: 260,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _kPrimaryDark,
                                _kPrimary,
                                _kPrimaryLight,
                              ],
                            ),
                          ),
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _HeroCircleButton(
                                    icon: Icons.chevron_left,
                                    onTap: () => Navigator.of(context).pop(),
                                  ),
                                  const Text(
                                    'JOIN GROUP',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  _HeroCircleButton(
                                    icon: Icons.more_horiz,
                                    onTap: () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Floating avatar (overlaps hero bottom)
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
                                        color:
                                            _kPrimary.withValues(alpha: 0.35),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: group.imageUrl != null &&
                                          group.imageUrl!.isNotEmpty
                                      ? ClipOval(
                                          child: CachedNetworkImage(
                                            imageUrl: group.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorWidget:
                                                (_, __, ___) => _avatarFallback(firstLetter),
                                          ),
                                        )
                                      : _avatarFallback(firstLetter),
                                ),
                                // Online dot
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: _kOnline,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ────────────────────────────────────────────────────
                    // Name + subtitle + members pill
                    // ────────────────────────────────────────────────────
                    const SizedBox(height: 58),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            group.name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: _kPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            group.description.isNotEmpty
                                ? group.description
                                : 'No description available.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _kPrimaryDark.withValues(alpha: 0.60),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Members pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kPrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kPrimary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.group,
                                    size: 14, color: _kPrimary),
                                const SizedBox(width: 5),
                                Text(
                                  '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                                  style: const TextStyle(
                                    color: _kPrimary,
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

                    // ────────────────────────────────────────────────────
                    // Body cards (staggered)
                    // ────────────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Card 1 — Tags
                          _staggered(
                            0,
                            _TagsCard(
                              requiresApproval: requiresApproval,
                              isPublic: group.isPublic,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Card 2 — Info rows
                          _staggered(1, _InfoCard(memberCount: memberCount)),
                          const SizedBox(height: 12),

                          // Card 3 — About
                          _staggered(
                            2,
                            _AboutCard(
                              description: group.description.isNotEmpty
                                  ? group.description
                                  : 'No description provided.',
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Card 4 — Buttons
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
                                    requiresApproval: requiresApproval,
                                    shimmerAnim: _shimmerAnim,
                                    onPressed: () {
                                      final auth =
                                          context.read<AuthProvider>();
                                      if (!auth.isAuthenticated) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'يجب تسجيل الدخول أولاً.'),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                        return;
                                      }
                                      context
                                          .read<GroupJoinRequestBloc>()
                                          .add(SubmitJoinRequest(
                                            inviteToken: widget.token,
                                            userId: auth.userId!,
                                            metadata: {
                                              'name': auth.currentUser
                                                      ?.name ??
                                                  'Unknown User',
                                              'avatarUrl': auth
                                                  .currentUser?.avatarUrl,
                                            },
                                          ));
                                    },
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

          return const SizedBox.shrink();
        },
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

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

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
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
  final bool requiresApproval;
  final bool isPublic;
  const _TagsCard({required this.requiresApproval, required this.isPublic});

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      child: Wrap(
        spacing: 10,
        children: [
          _TagChip(
            icon: isPublic ? Icons.public : Icons.lock,
            label: isPublic ? 'Public' : 'Private',
            bg: _kTagPurpleBg,
            fg: _kTagPurpleFg,
          ),
          _TagChip(
            icon: requiresApproval
                ? Icons.verified_user
                : Icons.bolt_rounded,
            label:
                requiresApproval ? 'Requires Approval' : 'Instant Join',
            bg: _kTagBlueBg,
            fg: _kTagBlueFg,
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
  const _TagChip(
      {required this.icon,
      required this.label,
      required this.bg,
      required this.fg});

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
  const _InfoCard({required this.memberCount});

  @override
  Widget build(BuildContext context) {
    return _BaseCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Row 1
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _LeadingBox(
                    bg: _kTagPurpleBg,
                    icon: Icons.group,
                    color: _kPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Members',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(
                        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _kPrimaryDark),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kActiveBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Active',
                      style: TextStyle(
                          color: _kActiveFg,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.grey.shade200,
              indent: 16,
              endIndent: 16),
          // Row 2
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _LeadingBox(
                    bg: _kTagBlueBg,
                    icon: Icons.access_time,
                    color: const Color(0xFF185FA5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Review time',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      const Text('~24 hours',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _kPrimaryDark)),
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
  const _LeadingBox(
      {required this.bg, required this.icon, required this.color});

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
  const _AboutCard({required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kTagPurpleBg, _kTagBlueBg],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7F77DD).withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ABOUT THIS GROUP',
            style: TextStyle(
              color: _kPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: _kPrimaryDark,
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
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(
          text:
              'https://university-connect-52779.web.app/group/invite?token=$token',
        ));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم نسخ رابط الدعوة!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.copy, color: _kPrimary, size: 20),
            const SizedBox(height: 3),
            Text('Copy link',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}

class _ShimmerJoinButton extends StatelessWidget {
  final bool requiresApproval;
  final Animation<double> shimmerAnim;
  final VoidCallback onPressed;
  const _ShimmerJoinButton({
    required this.requiresApproval,
    required this.shimmerAnim,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedBuilder(
        animation: shimmerAnim,
        builder: (_, __) {
          final x = shimmerAnim.value;
          return Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment(x - 1.0, 0),
                end: Alignment(x + 1.0, 0),
                colors: const [
                  _kPrimary,
                  _kPrimaryLight,
                  Color(0xFFA99EF0),
                  _kPrimaryLight,
                  _kPrimary,
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: _kPrimary.withValues(alpha: 0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.send, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  requiresApproval ? 'Request Join' : 'Join Group',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Error screen
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorScreen extends StatelessWidget {
  final String message;
  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_off_rounded,
                      size: 56, color: AppTheme.error),
                ),
                const SizedBox(height: 24),
                const Text(
                  'رابط غير صالح',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kPrimaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'رجوع',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
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
