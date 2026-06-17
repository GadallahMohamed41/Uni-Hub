import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme.dart';
import '../bloc/community_detail/community_detail_bloc.dart';
import '../bloc/community_detail/community_detail_event.dart';
import '../bloc/community_detail/community_detail_state.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/community_member_entity.dart';

class CommunityAdminScreen extends StatelessWidget {
  final CommunityEntity community;
  final String currentUserId;

  const CommunityAdminScreen({
    super.key,
    required this.community,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
        appBar: AppBar(
          title: const Text(
            'Admin Panel',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: isDark ? const Color(0xFF111827) : AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Container(
              color: isDark ? const Color(0xFF111827) : AppTheme.primary,
              child: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: [
                  Tab(text: 'Members'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Groups'),
                ],
              ),
            ),
          ),
        ),
        body: BlocBuilder<CommunityDetailBloc, CommunityDetailState>(
          builder: (context, state) {
            if (state is! CommunityDetailLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final loaded = state;
            return TabBarView(
              children: [
                _MembersTab(
                  loaded: loaded,
                  currentUserId: currentUserId,
                  communityId: community.id,
                  isDark: isDark,
                ),
                _RequestsTab(
                  loaded: loaded,
                  communityId: community.id,
                  actorId: currentUserId,
                  isDark: isDark,
                ),
                _GroupsTab(loaded: loaded, isDark: isDark),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Members Tab ───────────────────────────────────────────────────────────────

class _MembersTab extends StatelessWidget {
  final CommunityDetailLoaded loaded;
  final String currentUserId;
  final String communityId;
  final bool isDark;

  const _MembersTab({
    required this.loaded,
    required this.currentUserId,
    required this.communityId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final members = loaded.members;

    if (members.isEmpty) {
      return _EmptyState(
        icon: Icons.people_outline_rounded,
        label: 'No members yet',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = members[i];
        final isMe = m.userId == currentUserId;
        final isMeSuperAdmin = loaded.isSuperAdmin;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  m.userId.isNotEmpty ? m.userId[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMe ? '${m.userId} (You)' : m.userId,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark ? Colors.white : AppTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RoleChip(role: m.role),
                  ],
                ),
              ),

              // Actions
              if (!isMe && m.role != CommunityRole.superAdmin)
                PopupMenuButton<String>(
                  onSelected: (action) =>
                      _handleAction(context, action, m),
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.textSecondary,
                  ),
                  itemBuilder: (_) => [
                    if (m.role == CommunityRole.member && isMeSuperAdmin)
                      const PopupMenuItem(
                        value: 'promote',
                        child: ListTile(
                          leading: Icon(Icons.star_rounded,
                              color: AppTheme.warning),
                          title: Text('Make Admin'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    if (m.role == CommunityRole.admin && isMeSuperAdmin)
                      const PopupMenuItem(
                        value: 'demote',
                        child: ListTile(
                          leading: Icon(Icons.star_border_rounded),
                          title: Text('Remove Admin'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: Icon(Icons.person_remove_rounded,
                            color: AppTheme.error),
                        title: Text('Remove',
                            style: TextStyle(color: AppTheme.error)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleAction(
      BuildContext context, String action, CommunityMemberEntity m) {
    final bloc = context.read<CommunityDetailBloc>();
    switch (action) {
      case 'promote':
        bloc.add(CommunityDetailPromoteAdmin(
          communityId: communityId,
          targetUserId: m.userId,
          actorId: currentUserId,
        ));
        break;
      case 'demote':
        bloc.add(CommunityDetailDemoteAdmin(
          communityId: communityId,
          targetUserId: m.userId,
          actorId: currentUserId,
        ));
        break;
      case 'remove':
        bloc.add(CommunityDetailRemoveMember(
          communityId: communityId,
          targetUserId: m.userId,
          actorId: currentUserId,
        ));
        break;
    }
  }
}

// ── Join Requests Tab ─────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  final CommunityDetailLoaded loaded;
  final String communityId;
  final String actorId;
  final bool isDark;

  const _RequestsTab({
    required this.loaded,
    required this.communityId,
    required this.actorId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final requests = loaded.joinRequests;

    if (requests.isEmpty) {
      return _EmptyState(
        icon: Icons.inbox_rounded,
        label: 'No pending requests',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: requests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final req = requests[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  req.userName.isNotEmpty
                      ? req.userName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Text(
                  req.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? Colors.white : AppTheme.textMain,
                  ),
                ),
              ),

              // Approve / Deny buttons
              Row(
                children: [
                  _ActionBtn(
                    icon: Icons.close_rounded,
                    color: AppTheme.error,
                    onTap: () =>
                        context.read<CommunityDetailBloc>().add(
                              CommunityDetailDenyRequest(
                                communityId: communityId,
                                requestId: req.id,
                                actorId: actorId,
                              ),
                            ),
                  ),
                  const SizedBox(width: 8),
                  _ActionBtn(
                    icon: Icons.check_rounded,
                    color: AppTheme.success,
                    onTap: () =>
                        context.read<CommunityDetailBloc>().add(
                              CommunityDetailApproveRequest(
                                communityId: communityId,
                                requestId: req.id,
                                userId: req.userId,
                                userName: req.userName,
                                userAvatarUrl: req.userAvatarUrl,
                                actorId: actorId,
                              ),
                            ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Groups Tab ────────────────────────────────────────────────────────────────

class _GroupsTab extends StatelessWidget {
  final CommunityDetailLoaded loaded;
  final bool isDark;
  const _GroupsTab({required this.loaded, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final groups = loaded.regularGroups;

    if (groups.isEmpty) {
      return _EmptyState(
        icon: Icons.forum_outlined,
        label: 'No groups yet',
        isDark: isDark,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final g = groups[i];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                backgroundImage:
                    g.imageUrl != null ? CachedNetworkImageProvider(g.imageUrl!) : null,
                child: g.imageUrl == null
                    ? Text(
                        g.name.isNotEmpty ? g.name[0].toUpperCase() : 'G',
                        style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: isDark ? Colors.white : AppTheme.textMain,
                        )),
                    Text(
                      '${g.memberIds.length} members',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              if (loaded.isSuperAdmin)
                IconButton(
                  icon: const Icon(Icons.link_off_rounded,
                      color: AppTheme.error, size: 20),
                  tooltip: 'Detach',
                  onPressed: () => _confirmDetach(context, g.id, g.name),
                ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDetach(BuildContext context, String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Detach Group?'),
        content: Text(
            '"$groupName" will become a standalone group. Members will not be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<CommunityDetailBloc>()
                  .add(CommunityDetailRemoveGroup(groupId));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white),
            child: const Text('Detach'),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  final CommunityRole role;
  const _RoleChip({required this.role});

  @override
  Widget build(BuildContext context) {
    final color = role == CommunityRole.superAdmin
        ? AppTheme.accent
        : role == CommunityRole.admin
            ? AppTheme.warning
            : AppTheme.textSecondary;
    final label = role == CommunityRole.superAdmin
        ? 'Super Admin'
        : role == CommunityRole.admin
            ? 'Admin'
            : 'Member';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  const _EmptyState(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.5)
                  : AppTheme.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

