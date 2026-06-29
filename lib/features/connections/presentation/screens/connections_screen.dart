import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/config/i18n.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:project_test2/features/chat/presentation/screens/direct_message_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/connections/data/repositories/connections_repository.dart';
import 'package:project_test2/features/connections/presentation/bloc/connections_bloc.dart';

// ─── Entry Widget ──────────────────────────────────────────────────────────────
class ConnectionsScreen extends StatelessWidget {
  final int initialTabIndex;
  const ConnectionsScreen({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context) {
    final currentUser = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text('Sign in first')));
    }

    return BlocProvider<ConnectionsBloc>(
      create: (_) => ConnectionsBloc(
        repository: ConnectionsRepository(FirebaseFirestore.instance),
        currentUserId: currentUser.uid,
      )..add(const ConnectionsStarted()),
      child: _ConnView(initialTabIndex: initialTabIndex),
    );
  }
}

// ─── Main stateful view ────────────────────────────────────────────────────────
class _ConnView extends StatefulWidget {
  final int initialTabIndex;
  const _ConnView({this.initialTabIndex = 0});
  @override
  State<_ConnView> createState() => _ConnViewState();
}

class _ConnViewState extends State<_ConnView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tab;
  final TextEditingController _search = TextEditingController();
  final FirestoreService _fs = FirestoreService();

  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  bool _searchLoading = false;

  // locally dismissed suggestion ids
  final Set<String> _dismissed = {};
  late int _currentTabIndex;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _tab = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTabIndex);
    _tab.addListener(() {
      if (_tab.index != _currentTabIndex && !_tab.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tab.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String v) async {
    final q = v.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _searchLoading = true;
    });
    final r = await _fs.searchUsers(q);
    if (!mounted) return;
    setState(() {
      _searchResults = r;
      _searchLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildHeader(theme, isDark),
        ],
        body: _isSearching
            ? _buildSearchResults()
            : TabBarView(
                controller: _tab,
                children: [
                  _GrowTab(
                    dismissed: _dismissed,
                    onDismiss: (id) => setState(() => _dismissed.add(id)),
                    onGoToNetwork: () => _tab.animateTo(1),
                  ),
                  const _CatchUpTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return SliverAppBar(
      pinned: true,
      snap: false,
      floating: false,
      centerTitle: false,
      automaticallyImplyLeading: false,
      backgroundColor: theme.colorScheme.surface,
      elevation: 0,
      toolbarHeight: 0,
      expandedHeight: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(182),
        child: _NetworkHeader(
          tab: _tab,
          search: _search,
          isSearching: _isSearching,
          currentTabIndex: _currentTabIndex,
          onSearch: _onSearch,
          onClearSearch: () {
            _search.clear();
            setState(() {
              _isSearching = false;
              _searchResults = [];
            });
          },
          onTabChanged: (index) {
            setState(() => _currentTabIndex = index);
            _tab.animateTo(index);
          },
        ),
      ),
    );
  }


  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return _EmptyPlaceholder(
        icon: Icons.search_off_rounded,
        title: context.tr(en: 'No users found', ar: 'لا يوجد مستخدمون'),
        subtitle: context.tr(en: 'Try another name', ar: 'جرّب اسمًا آخر'),
      );
    }
    final auth = context.read<AuthProvider>();
    final bloc = context.read<ConnectionsBloc>();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) {
        final u = _searchResults[i];
        if (u.uid == auth.currentUser?.uid) return const SizedBox.shrink();
        return _InvitationCard(
          user: u,
          onAccept: () => bloc.add(ConnectionsSendRequestPressed(u.uid)),
          onIgnore: null,
          acceptLabel: context.tr(en: 'Connect', ar: 'اتصال'),
          acceptIcon: Icons.person_add_rounded,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GROW TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _GrowTab extends StatelessWidget {
  final Set<String> dismissed;
  final void Function(String id) onDismiss;
  final VoidCallback onGoToNetwork;

  const _GrowTab(
      {required this.dismissed,
      required this.onDismiss,
      required this.onGoToNetwork});

  @override
  Widget build(BuildContext context) {


    return BlocBuilder<ConnectionsBloc, ConnectionsState>(
      builder: (context, state) {
        final bloc = context.read<ConnectionsBloc>();

        final pending = state.incomingRequests;
        final suggested = state.suggestedUsers
            .where((u) => !dismissed.contains(u.uid))
            .toList();

        return RefreshIndicator(
          onRefresh: () async =>
              bloc.add(const ConnectionsSuggestedUsersRequested()),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              // ── Stats banner removed ─────────────────────────────────

              // ── Invitations ──────────────────────────────────────────
              if (pending.isNotEmpty) ...[
                _GroupHeader(
                  title: 'Invitations',
                  count: pending.length,
                  onSeeAll: null,
                ),
                // summary pill
                if (pending.length > 1)
                  _AcceptedSummaryPill(users: pending.take(3).toList()),
                ...pending.map((u) => _InvitationCard(
                      user: u,
                      onAccept: () =>
                          bloc.add(ConnectionsAcceptRequestPressed(u.uid)),
                      onIgnore: () =>
                          bloc.add(ConnectionsIgnoreRequestPressed(u.uid)),
                      acceptLabel: 'Accept',
                      acceptIcon: Icons.check_rounded,
                    )),
                const SizedBox(height: 8),
              ],

              // ── Manage network removed ───────────────────────────────

              // ── People you may know ──────────────────────────────────
              _GroupHeader(
                title: 'People you may know',
                count: suggested.length,
                onSeeAll: null,
                trailing: state.isLoadingSuggestions
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),

              if (state.isLoadingSuggestions && suggested.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (suggested.isEmpty)
                _EmptyPlaceholder(
                  icon: Icons.explore_off_rounded,
                  title: 'No suggestions',
                  subtitle: 'We\u2019ll show new members here',
                  compact: true,
                )
              else
                _SuggestionGrid(
                  users: suggested,
                  sentRequests: state.sentRequests,
                  actionInProgressUserId: state.actionInProgressUserId,
                  onConnect: (u) {
                    if (!state.sentRequests.contains(u.uid)) {
                      bloc.add(ConnectionsSendRequestPressed(u.uid));
                    }
                  },
                  onDismiss: onDismiss,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CATCH UP TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _CatchUpTab extends StatelessWidget {
  const _CatchUpTab();

  @override
  Widget build(BuildContext context) {


    return BlocBuilder<ConnectionsBloc, ConnectionsState>(
      builder: (context, state) {
        if (state.isLoading && state.connections.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.connections.isEmpty) {
          return _EmptyPlaceholder(
            icon: Icons.group_rounded,
            title: 'No connections yet',
            subtitle: 'Head to Grow to start connecting',
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _GroupHeader(
                title: 'My Connections',
                count: state.connections.length,
                onSeeAll: null),
            ...state.connections.asMap().entries.map((e) {
              return _ConnectionTile(user: e.value, index: e.key);
            }),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════════════════


class _AcceptedSummaryPill extends StatelessWidget {
  final List<UserModel> users;
  const _AcceptedSummaryPill({required this.users});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 8,
          )
        ],
      ),
      child: Row(
        children: [
          // stacked avatars
          SizedBox(
            width: 48,
            height: 32,
            child: Stack(
              children: [
                ...users.take(2).toList().asMap().entries.map((e) {
                  final url = (e.value.avatarUrl ?? '').trim();
                  return Positioned(
                    left: e.key * 16.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              isDark ? const Color(0xFF111827) : Colors.white,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                        backgroundImage: url.isNotEmpty
                            ? CachedNetworkImageProvider(url, maxWidth: 100, maxHeight: 100)
                            : null,
                        child: url.isEmpty
                            ? Text(
                                e.value.name.isNotEmpty ? e.value.name[0] : '?',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary))
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${users.first.name.split(' ').first} and ${users.length - 1} others sent you invitations. View all',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Invitation card (accept / ignore)
class _InvitationCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onAccept;
  final VoidCallback? onIgnore;
  final String acceptLabel;
  final IconData acceptIcon;

  const _InvitationCard({
    required this.user,
    required this.onAccept,
    required this.onIgnore,
    required this.acceptLabel,
    required this.acceptIcon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final url = (user.avatarUrl ?? '').trim();
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141E30) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with gradient ring
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(userId: user.uid),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                ),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor:
                    isDark ? const Color(0xFF1E293B) : AppTheme.surfaceVariant,
                backgroundImage:
                    url.isNotEmpty ? CachedNetworkImageProvider(url, maxWidth: 120, maxHeight: 120) : null,
                child: url.isEmpty
                    ? Text(initials,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary))
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if ((user.bio ?? '').isNotEmpty)
                  Text(
                    user.bio!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                if (user.connectionsCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '${user.connectionsCount} mutual connections',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          Column(
            children: [
              if (onIgnore != null)
                _CircleActionBtn(
                  icon: Icons.close_rounded,
                  onTap: onIgnore!,
                  filled: false,
                  color: AppTheme.textSecondary,
                ),
              if (onIgnore != null) const SizedBox(height: 6),
              _CircleActionBtn(
                icon: acceptIcon,
                onTap: onAccept ?? () {},
                filled: true,
                color: AppTheme.primary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;
  final Color color;

  const _CircleActionBtn({
    required this.icon,
    required this.onTap,
    required this.filled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: filled ? Colors.white : color, size: 18),
      ),
    );
  }
}



/// Suggestion grid (2-column card layout with × dismiss)
class _SuggestionGrid extends StatelessWidget {
  final List<UserModel> users;
  final Set<String> sentRequests;
  final String? actionInProgressUserId;
  final void Function(UserModel) onConnect;
  final void Function(String) onDismiss;

  const _SuggestionGrid({
    required this.users,
    required this.sentRequests,
    this.actionInProgressUserId,
    required this.onConnect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: users.length,
        itemBuilder: (_, i) {
          final u = users[i];
          final url = (u.avatarUrl ?? '').trim();

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + i * 60),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(
                scale: v, child: Opacity(opacity: v.clamp(0, 1), child: child)),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141E30) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Top gradient bg
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.7),
                              AppTheme.secondary.withValues(alpha: 0.7),
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20)),
                        ),
                      ),
                      // Avatar overlapping
                      const SizedBox(height: 36),
                      // Name & bio
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Column(
                          children: [
                            Text(
                              u.name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if ((u.bio ?? '').isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                u.bio!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                            if (u.connectionsCount > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${u.connectionsCount} connections',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textTertiary),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Connect button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        child: Builder(builder: (context) {
                          final isRequested = sentRequests.contains(u.uid);
                          final isLoading = actionInProgressUserId == u.uid;
                          
                          if (isRequested) {
                            return Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: AppTheme.success.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: AppTheme.success, size: 14),
                                  SizedBox(width: 5),
                                  Text('Pending',
                                      style: TextStyle(
                                          color: AppTheme.success,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            );
                          }
                          
                          return GestureDetector(
                            onTap: isLoading ? null : () => onConnect(u),
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isLoading
                                      ? [Colors.grey.shade400, Colors.grey.shade500]
                                      : [AppTheme.primary, AppTheme.secondary],
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: isLoading ? null : [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isLoading)
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    const Icon(Icons.person_add_rounded,
                                        color: Colors.white, size: 14),
                                  const SizedBox(width: 5),
                                  Text(isLoading ? 'Sending...' : 'Connect',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  // Avatar centered on gradient
                  Positioned(
                    top: 28,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(userId: u.uid),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 34,
                            backgroundColor:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            backgroundImage: url.isNotEmpty
                                ? CachedNetworkImageProvider(url, maxWidth: 150, maxHeight: 150)
                                : null,
                            child: url.isEmpty
                                ? Text(
                                    u.name.isNotEmpty
                                        ? u.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.primary),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Dismiss X button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => onDismiss(u.uid),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Connected user tile in Catch Up tab
class _ConnectionTile extends StatefulWidget {
  final UserModel user;
  final int index;
  const _ConnectionTile({required this.user, required this.index});

  @override
  State<_ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends State<_ConnectionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 60), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showConnectedMenu(BuildContext context, Offset tapPosition) async {
    final u = widget.user;
    final bloc = context.read<ConnectionsBloc>();
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromLTRB(
      tapPosition.dx - 160,
      tapPosition.dy - 10,
      overlay.size.width - tapPosition.dx + 10,
      overlay.size.height - tapPosition.dy - 40,
    );

    final result = await showMenu<String>(
      context: context,
      position: position,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      items: [
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_remove_rounded,
                    color: AppTheme.error, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Remove Connection',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppTheme.error)),
            ],
          ),
        ),
      ],
    );

    if (!context.mounted) return;
    if (result == 'remove') {
      bloc.add(ConnectionsRemovePressed(u.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final url = (u.avatarUrl ?? '').trim();

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141E30) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Green left accent bar
                  Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppTheme.success, Color(0xFF34D399)],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Top row: avatar + name / bio ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          UserProfileScreen(userId: u.uid),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.success,
                                        Color(0xFF34D399)
                                      ],
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : Colors.white,
                                    backgroundImage: url.isNotEmpty
                                        ? CachedNetworkImageProvider(url, maxWidth: 120, maxHeight: 120)
                                        : null,
                                    child: url.isEmpty
                                        ? Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: AppTheme.success))
                                        : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name + bio — full remaining width, never truncated
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        height: 1.25,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    if ((u.bio ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        u.bio!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // ── Bottom row: message + connected ──
                          Row(
                            children: [
                              // Message button
                              GestureDetector(
                                  onTap: () async {
                                  final me = context.read<AuthProvider>().currentUser;
                                  if (me == null) return;
                                  final repo = ChatRepositoryImpl();
                                  final conv = await repo.getOrCreateConversation(
                                    myId: me.uid,
                                    myName: me.name,
                                    myAvatar: me.avatarUrl,
                                    otherId: u.uid,
                                    otherName: u.name,
                                    otherAvatar: u.avatarUrl,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DirectMessageScreen(
                                        conversationId: conv.id,
                                        otherUserId: u.uid,
                                        otherUserName: u.name,
                                        otherUserAvatar: u.avatarUrl,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            AppTheme.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: AppTheme.primary,
                                          size: 14),
                                      SizedBox(width: 6),
                                      Text('Message',
                                          style: TextStyle(
                                              color: AppTheme.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Connected pill → popup menu on tap
                              GestureDetector(
                                onTapDown: (details) => _showConnectedMenu(
                                    context, details.globalPosition),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color:
                                            AppTheme.success.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle_rounded,
                                          size: 13, color: AppTheme.success),
                                      SizedBox(width: 4),
                                      Text('Connected',
                                          style: TextStyle(
                                              color: AppTheme.success,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                      SizedBox(width: 3),
                                      Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: AppTheme.success),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Group header (title + count badge + optional trailing)

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onSeeAll;
  final Widget? trailing;

  const _GroupHeader({
    required this.title,
    required this.count,
    required this.onSeeAll,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: [
          Text(
            count > 0 ? '$title ($count)' : title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Icon(Icons.arrow_forward_rounded,
                  color: AppTheme.primary, size: 20),
            ),
        ],
      ),
    );
  }
}

/// Reusable empty state
class _EmptyPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  const _EmptyPlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.all(compact ? 16 : 32),
      padding: EdgeInsets.all(compact ? 20 : 36),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.primary, size: compact ? 26 : 38),
          ),
          SizedBox(height: compact ? 10 : 16),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 15 : 18,
                  color: theme.colorScheme.onSurface)),
          const SizedBox(height: 4),
          Text(subtitle,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// PREMIUM NETWORK HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _NetworkHeader extends StatelessWidget {
  final TabController tab;
  final TextEditingController search;
  final bool isSearching;
  final int currentTabIndex;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onTabChanged;

  const _NetworkHeader({
    required this.tab,
    required this.search,
    required this.isSearching,
    required this.currentTabIndex,
    required this.onSearch,
    required this.onClearSearch,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = theme.colorScheme.surface;
    final onSurfaceColor = theme.colorScheme.onSurface;
    final primaryColor = theme.colorScheme.primary;

    // Search bar background
    final searchBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final searchBorderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);

    return Container(
      color: bgColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Hero Banner ───────────────────────────────────────────────────
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Network node icon badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.hub_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'My Network',
                        style: TextStyle(
                          color: onSurfaceColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Connect & Grow',
                            style: TextStyle(
                              color: onSurfaceColor.withValues(alpha: 0.5),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Trailing badge
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onSurfaceColor.withValues(alpha: 0.05),
                  ),
                  child: Icon(
                    Icons.people_alt_rounded,
                    color: onSurfaceColor.withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),

          // ── Search Bar ───────────────────────────────────────────────────
          Container(
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: searchBg,
              borderRadius: BorderRadius.circular(23),
              border: Border.all(
                color: isSearching
                    ? primaryColor.withValues(alpha: 0.5)
                    : searchBorderColor,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: isSearching
                      ? primaryColor
                      : onSurfaceColor.withValues(alpha: 0.4),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: search,
                    style: TextStyle(
                      color: onSurfaceColor,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search people...',
                      hintStyle: TextStyle(
                        color: onSurfaceColor.withValues(alpha: 0.35),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      filled: false,
                    ),
                    onChanged: onSearch,
                  ),
                ),
                if (isSearching)
                  GestureDetector(
                    onTap: onClearSearch,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: onSurfaceColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: onSurfaceColor.withValues(alpha: 0.6),
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tab Switcher ─────────────────────────────────────────────────
          Container(
            height: 46,
            margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: _PillTabSwitcher(
              selectedIndex: currentTabIndex,
              onChanged: onTabChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pill Tab Switcher ──────────────────────────────────────────────────────────
class _PillTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const _PillTabSwitcher({
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final tabBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final tabBorderColor = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08);
    final primaryColor = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tabBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: tabBorderColor,
          width: 1,
        ),
      ),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final half = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Sliding pill (Instant position, no animation)
              Positioned(
                top: 0,
                bottom: 0,
                left: selectedIndex == 0 ? 0 : half,
                width: half,
                child: Container(
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),

              // Tab buttons
              Row(
                children: [
                  _TabBtn(
                    label: 'GROW',
                    icon: Icons.person_add_alt_1_rounded,
                    active: selectedIndex == 0,
                    onTap: () => onChanged(0),
                  ),
                  _TabBtn(
                    label: 'CATCH UP',
                    icon: Icons.forum_rounded,
                    active: selectedIndex == 1,
                    onTap: () => onChanged(1),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _TabBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? theme.colorScheme.onPrimary
                    : onSurfaceColor.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: active
                      ? theme.colorScheme.onPrimary
                      : onSurfaceColor.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
