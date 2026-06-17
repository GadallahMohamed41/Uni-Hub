import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/group_join_request_repository_impl.dart';
import '../../data/repositories/group_invite_repository_impl.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/group_join_request_entity.dart';
import '../bloc/group_join_request/group_join_request_bloc.dart';
import '../bloc/group_join_request/group_join_request_event.dart';
import '../bloc/group_join_request/group_join_request_state.dart';

class RequestItem {
  final String id;
  final String userId;
  final String name;
  final String initial;
  final String date;
  final String badge;
  final String? avatarUrl;
  bool isRemoving;
  String removeType;

  RequestItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.initial,
    required this.date,
    required this.badge,
    this.avatarUrl,
    this.isRemoving = false,
    this.removeType = '',
  });
}

class AdminRequestsScreen extends StatefulWidget {
  final String groupId;

  const AdminRequestsScreen({super.key, required this.groupId});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen>
    with TickerProviderStateMixin {
  List<RequestItem> _requests = [];
  int _acceptedCount = 0;
  bool _acceptingAll = false;
  bool _initialized = false;

  String _getBadgeText(DateTime requestedAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final requestDate = DateTime(requestedAt.year, requestedAt.month, requestedAt.day);

    if (requestDate == today) {
      return 'Today';
    } else if (requestDate == yesterday) {
      return 'Yesterday';
    } else {
      final diff = today.difference(requestDate).inDays;
      if (diff <= 1) {
        return 'Older';
      }
      return '$diff days ago';
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  void _syncRequests(List<GroupJoinRequestEntity> firestoreRequests) {
    if (_acceptingAll) return;

    final List<RequestItem> updatedList = [];

    for (final freq in firestoreRequests) {
      final existingIndex = _requests.indexWhere((r) => r.id == freq.requestId);

      if (existingIndex != -1) {
        final existingItem = _requests[existingIndex];
        if (existingItem.isRemoving) {
          updatedList.add(existingItem);
        } else {
          updatedList.add(RequestItem(
            id: freq.requestId,
            userId: freq.userId,
            name: freq.userName,
            initial: freq.userName.isNotEmpty ? freq.userName[0].toUpperCase() : '?',
            date: _formatDate(freq.requestedAt),
            badge: _getBadgeText(freq.requestedAt),
            avatarUrl: freq.userAvatarUrl,
            isRemoving: false,
            removeType: '',
          ));
        }
      } else {
        updatedList.add(RequestItem(
          id: freq.requestId,
          userId: freq.userId,
          name: freq.userName,
          initial: freq.userName.isNotEmpty ? freq.userName[0].toUpperCase() : '?',
          date: _formatDate(freq.requestedAt),
          badge: _getBadgeText(freq.requestedAt),
          avatarUrl: freq.userAvatarUrl,
          isRemoving: false,
          removeType: '',
        ));
      }
    }

    for (final req in _requests) {
      if (req.isRemoving && !updatedList.any((r) => r.id == req.id)) {
        updatedList.add(req);
      }
    }

    setState(() {
      _requests = updatedList;
      _initialized = true;
    });
  }

  void _removeRequestFromState(String id) {
    if (!mounted) return;
    setState(() {
      _requests.removeWhere((r) => r.id == id);
      if (_requests.isEmpty) {
        _acceptingAll = false;
      }
    });
  }

  void _acceptAll(BuildContext context) async {
    if (_requests.isEmpty || _acceptingAll) return;
    setState(() {
      _acceptingAll = true;
    });

    final bloc = context.read<GroupJoinRequestBloc>();
    final active = _requests.where((r) => !r.isRemoving).toList();
    for (int i = 0; i < active.length; i++) {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return;
      
      final req = active[i];
      setState(() {
        final item = _requests.firstWhere((r) => r.id == req.id);
        item.isRemoving = true;
        item.removeType = 'accept';
        _acceptedCount++;
      });

      // Fire the Bloc Event to approve
      bloc.add(
        UpdateJoinRequestStatus(
          requestId: req.id,
          groupId: widget.groupId,
          userId: req.userId,
          userName: req.name,
          userAvatarUrl: req.avatarUrl,
          status: GroupJoinRequestStatus.approved,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocProvider(
      create: (_) => GroupJoinRequestBloc(
        inviteRepository: GroupInviteRepositoryImpl(firestore: FirebaseFirestore.instance),
        joinRequestRepository: GroupJoinRequestRepositoryImpl(firestore: FirebaseFirestore.instance),
        groupRepository: GroupRepositoryImpl(firestore: FirebaseFirestore.instance),
      )..add(LoadGroupJoinRequests(groupId: widget.groupId)),
      child: BlocConsumer<GroupJoinRequestBloc, GroupJoinRequestState>(
        listener: (context, state) {
          if (state is GroupJoinRequestError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is GroupJoinRequestsLoaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _syncRequests(state.requests);
            });
          }

          final pendingCount = _requests.where((r) => !r.isRemoving).length;
          final totalCount = pendingCount + _acceptedCount;
          final todayCount = _requests
              .where((r) => !r.isRemoving && r.badge == 'Today')
              .length;

          final showLoading = !_initialized && state is GroupJoinRequestLoading;

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            body: Column(
              children: [
                // ── Header (Gradient background) ──────────────────────────────────
                _buildHeader(context, totalCount, pendingCount, todayCount),

                // ── Body Scrollable Content ────────────────────────────────────────
                Expanded(
                  child: showLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pendingCount > 0) ...[
                                // Section Label
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10, left: 4),
                                  child: Text(
                                    'PENDING REQUESTS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),

                                // Cards list
                                ...List.generate(_requests.length, (index) {
                                  final req = _requests[index];
                                  final delay = Duration(milliseconds: index * 80);
                                  return _AnimatedRequestCard(
                                    key: ValueKey(req.id),
                                    item: req,
                                    delay: delay,
                                    onAccept: () {
                                      setState(() {
                                        _acceptedCount++;
                                        req.isRemoving = true;
                                        req.removeType = 'accept';
                                      });
                                      context.read<GroupJoinRequestBloc>().add(
                                            UpdateJoinRequestStatus(
                                              requestId: req.id,
                                              groupId: widget.groupId,
                                              userId: req.userId,
                                              userName: req.name,
                                              userAvatarUrl: req.avatarUrl,
                                              status: GroupJoinRequestStatus.approved,
                                            ),
                                          );
                                    },
                                    onReject: () {
                                      setState(() {
                                        req.isRemoving = true;
                                        req.removeType = 'reject';
                                      });
                                      context.read<GroupJoinRequestBloc>().add(
                                            UpdateJoinRequestStatus(
                                              requestId: req.id,
                                              groupId: widget.groupId,
                                              userId: req.userId,
                                              userName: req.name,
                                              userAvatarUrl: req.avatarUrl,
                                              status: GroupJoinRequestStatus.rejected,
                                            ),
                                          );
                                    },
                                    onAnimationComplete: () => _removeRequestFromState(req.id),
                                  );
                                }),

                                const SizedBox(height: 20),

                                // Accept All button
                                _buildAcceptAllButton(context),
                              ] else
                                // Empty State
                                _buildEmptyState(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    int total,
    int pending,
    int today,
  ) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 91, 79, 220),
            Color.fromARGB(255, 31, 13, 231),
            Color.fromARGB(255, 67, 60, 137),
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              // Custom top bar with back arrow and Title
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Join Requests',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 38), // Spacer to balance back button
                ],
              ),
              const SizedBox(height: 22),

              // Stat boxes row
              Row(
                children: [
                  Expanded(
                    child: _buildStatBox('Total', total.toString(), Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox(
                      'Pending',
                      pending.toString(),
                      const Color(0xFFA0F0C8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatBox('Today', today.toString(), Colors.white),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.65),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptAllButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF534AB7), Color(0xFF8B83E6)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF534AB7).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _acceptingAll ? null : () => _acceptAll(context),
          borderRadius: BorderRadius.circular(13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.done_all,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Accept All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_outlined,
                size: 64,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRequestCard extends StatefulWidget {
  final RequestItem item;
  final Duration delay;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onAnimationComplete;

  const _AnimatedRequestCard({
    required this.item,
    required this.delay,
    required this.onAccept,
    required this.onReject,
    required this.onAnimationComplete,
    super.key,
  });

  @override
  State<_AnimatedRequestCard> createState() => _AnimatedRequestCardState();
}

class _AnimatedRequestCardState extends State<_AnimatedRequestCard>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final AnimationController _exitCtrl;

  late final Animation<double> _entranceFade;
  late final Animation<Offset> _entranceSlide;

  late final Animation<double> _exitFade;
  late final Animation<Offset> _exitSlide;

  bool _isExiting = false;
  String _exitType = '';

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _entranceFade = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutQuad));

    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOutQuad));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _entranceCtrl.forward();
      }
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  void triggerExit(String type) {
    if (_isExiting) return;
    setState(() {
      _isExiting = true;
      _exitType = type;
    });

    if (type == 'accept') {
      _exitCtrl.forward().then((_) => widget.onAnimationComplete());
    } else {
      _exitCtrl.duration = const Duration(milliseconds: 250);
      _exitCtrl.forward().then((_) => widget.onAnimationComplete());
    }
  }

  @override
  void didUpdateWidget(covariant _AnimatedRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.isRemoving && !_isExiting) {
      triggerExit(widget.item.removeType);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = _buildCardContent();

    if (_isExiting) {
      if (_exitType == 'accept') {
        cardContent = SlideTransition(
          position: _exitSlide,
          child: FadeTransition(
            opacity: _exitFade,
            child: cardContent,
          ),
        );
      } else {
        cardContent = FadeTransition(
          opacity: _exitFade,
          child: cardContent,
        );
      }
    }

    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: cardContent,
      ),
    );
  }

  Widget _buildCardContent() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = widget.item.name;
    final initial = widget.item.initial.toUpperCase();
    final badge = widget.item.badge;

    // Avatar colors per user
    Color avatarBg;
    Color avatarText;
    if (initial == 'A') {
      avatarBg = const Color(0xFFEEEDFE);
      avatarText = const Color(0xFF3C3489);
    } else if (initial == 'M') {
      avatarBg = const Color(0xFFE6F1FB);
      avatarText = const Color(0xFF0C447C);
    } else if (initial == 'S') {
      avatarBg = const Color(0xFFFBEAF0);
      avatarText = const Color(0xFF72243E);
    } else {
      avatarBg = const Color(0xFFEEEDFE);
      avatarText = const Color(0xFF3C3489);
    }

    // Badge colors
    Color badgeBg;
    Color badgeText;
    if (badge == 'Today') {
      badgeBg = const Color(0xFFFAEEDA);
      badgeText = const Color(0xFF854F0B);
    } else if (badge == 'Yesterday') {
      badgeBg = const Color(0xFFEEEDFE);
      badgeText = const Color(0xFF3C3489);
    } else {
      badgeBg = const Color(0xFFF1EFE8);
      badgeText = const Color(0xFF444441);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: avatarBg,
            child: Text(
              initial,
              style: TextStyle(
                color: avatarText,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Requested on ${widget.item.date}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Row(
            children: [
              // Reject
              GestureDetector(
                onTap: () {
                  if (!_isExiting) {
                    widget.onReject();
                    triggerExit('reject');
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Color(0xFFA32D2D),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Accept
              GestureDetector(
                onTap: () {
                  if (!_isExiting) {
                    widget.onAccept();
                    triggerExit('accept');
                  }
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3DE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Color(0xFF3B6D11),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
