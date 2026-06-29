import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/community/data/repositories/community_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/presentation/bloc/community_detail/community_detail_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/community_detail/community_detail_event.dart';
import 'package:project_test2/features/community/presentation/bloc/community_detail/community_detail_state.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/announcement_banner.dart';
import 'package:project_test2/features/community/presentation/screens/community_admin_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_chat_screen.dart';
import 'package:project_test2/features/community/presentation/screens/create_group_screen.dart';
=======
import '../../../../../core/theme.dart';
import '../../../../../providers/auth_provider.dart';
import '../../data/repositories/community_repository_impl.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../bloc/community_detail/community_detail_bloc.dart';
import '../bloc/community_detail/community_detail_event.dart';
import '../bloc/community_detail/community_detail_state.dart';
import '../../domain/entities/community_entity.dart';
import '../../domain/entities/group_entity.dart';
import '../widgets/announcement_banner.dart';
import 'community_admin_screen.dart';
import 'group_chat_screen.dart';
import 'create_group_screen.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class CommunityDetailScreen extends StatelessWidget {
  final CommunityEntity community;

  const CommunityDetailScreen({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final myId = auth.currentUser?.uid ?? '';
    final myName = auth.currentUser?.name ?? 'User';
    final myAvatar = auth.currentUser?.avatarUrl;

    return BlocProvider(
      create: (_) => CommunityDetailBloc(
        repository: CommunityRepositoryImpl(),
        community: community,
        currentUserId: myId,
      ),
      child: _CommunityDetailView(
        myId: myId,
        myName: myName,
        myAvatar: myAvatar,
      ),
    );
  }
}

class _CommunityDetailView extends StatelessWidget {
  final String myId;
  final String myName;
  final String? myAvatar;

  const _CommunityDetailView({
    required this.myId,
    required this.myName,
    required this.myAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CommunityDetailBloc, CommunityDetailState>(
      listener: (context, state) {
        if (state is CommunityDetailLoaded && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context
              .read<CommunityDetailBloc>()
              .add(const CommunityDetailErrorCleared());
        }
      },
      builder: (context, state) {
        if (state is CommunityDetailLoading || state is CommunityDetailInitial) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (state is CommunityDetailError) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppTheme.primary),
            body: Center(child: Text(state.message)),
          );
        }

        final loaded = state as CommunityDetailLoaded;
        final community = loaded.community;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
          body: CustomScrollView(
            slivers: [
              // ── Hero Header ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 240,
                pinned: true,
                backgroundColor: isDark ? const Color(0xFF111827) : AppTheme.primary,
                elevation: 0,
                actions: [
                  if (loaded.isAdmin)
                    IconButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommunityAdminScreen(
                            community: community,
                            currentUserId: myId,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded,
                          color: Colors.white),
                      tooltip: 'Admin Panel',
                    ),
                  IconButton(
                    onPressed: () => _copyInviteLink(context, community),
                    icon: const Icon(Icons.link_rounded, color: Colors.white),
                    tooltip: 'Copy Invite Link',
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Cover image / gradient
                      community.imageUrl != null && community.imageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: community.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _gradientBackground(),
                              errorWidget: (_, __, ___) => _gradientBackground(),
                            )
                          : _gradientBackground(),

                      // Dark overlay gradient
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),

                      // Community info at bottom
                      Positioned(
                        bottom: 18,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              community.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _StatChip(
                                  icon: Icons.people_rounded,
                                  label: '${loaded.members.length} members',
                                ),
                                _StatChip(
                                  icon: Icons.forum_rounded,
                                  label: '${loaded.regularGroups.length} groups',
                                ),
                                _StatChip(
                                  icon: community.isPublic
                                      ? Icons.public_rounded
                                      : Icons.lock_rounded,
                                  label: community.isPublic ? 'Public' : 'Private',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Announcement Banner ─────────────────────────────────
                    AnnouncementBanner(
                      announcementGroup: loaded.announcementGroup,
                      isAdmin: loaded.isAdmin,
                      onTap: () => _openAnnouncementGroup(
                          context, loaded, loaded.announcementGroup),
                    ),

                    // ── Description ─────────────────────────────────────────
                    if (community.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF111827)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black
                                    .withValues(alpha: isDark ? 0.1 : 0.04),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            community.description,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // ── Groups Section Header ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Groups',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textMain,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const Spacer(),
                          if (loaded.isAdmin)
                            GestureDetector(
                              onTap: () =>
                                  _createGroupInCommunity(context, loaded),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Add',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // ── Horizontal Scrollable Group Cards ───────────────────
                    if (loaded.regularGroups.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF111827)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Text(
                              'No groups yet',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 118,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: loaded.regularGroups.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, i) {
                            final group = loaded.regularGroups[i];
                            return _GroupCard(
                              group: group,
                              isDark: isDark,
                              onTap: () =>
                                  _openGroup(context, loaded, group),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 24),

                    // ── Join button for non-members ──────────────────────────
                    if (!loaded.isMember)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => _join(context, community),
                              icon: const Icon(Icons.group_add_rounded,
                                  color: Colors.white),
                              label: Text(
                                community.isPublic
                                    ? 'Join Community'
                                    : 'Request to Join',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _gradientBackground() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
    );
  }

  void _copyInviteLink(BuildContext context, CommunityEntity community) {
    Clipboard.setData(ClipboardData(text: community.inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openGroup(
    BuildContext context,
    CommunityDetailLoaded loaded,
    GroupEntity group,
  ) async {
    if (myId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to open groups.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (group.isMember(myId)) {
      _pushGroupChat(context, group.id);
      return;
    }

    if (!loaded.isMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Join the community first to access groups.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final canJoinAsCommunityMember =
        group.isPublic || group.isAnnouncementOnly;
    if (!canJoinAsCommunityMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This group is private. Ask a community admin for access.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Joining group…'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      await GroupRepositoryImpl().addMembers(
        groupId: group.id,
        newMemberIds: [myId],
        newMemberNames: [myName],
        newMemberAvatarUrls: [myAvatar],
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      _pushGroupChat(context, group.id);
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not join group: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _pushGroupChat(BuildContext context, String groupId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(
          groupId: groupId,
          currentUserId: myId,
          currentUserName: myName,
          currentUserAvatarUrl: myAvatar,
        ),
      ),
    );
  }

  void _openAnnouncementGroup(
      BuildContext context, CommunityDetailLoaded loaded, GroupEntity? group) {
    if (group == null) return;
    _openGroup(context, loaded, group);
  }

  void _createGroupInCommunity(
      BuildContext context, CommunityDetailLoaded loaded) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateGroupScreen(
          currentUserId: myId,
          currentUserName: myName,
          currentUserAvatarUrl: myAvatar,
          communityId: loaded.community.id,
          onGroupCreated: (name, desc, memberIds, imageUrl, isPublic) {
            context.read<CommunityDetailBloc>().add(
                  CommunityDetailCreateGroup(
                    communityId: loaded.community.id,
                    name: name,
                    description: desc,
                    ownerId: myId,
                    ownerName: myName,
                    ownerAvatarUrl: myAvatar,
                    imageUrl: imageUrl,
                  ),
                );
          },
        ),
      ),
    );
  }

  void _join(BuildContext context, CommunityEntity community) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Use the invite link to join this community'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Group Card ─────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final GroupEntity group;
  final bool isDark;
  final VoidCallback onTap;

  const _GroupCard({
    required this.group,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth =
        (MediaQuery.sizeOf(context).width * 0.26).clamp(100.0, 118.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Group image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: group.imageUrl != null && group.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: group.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _fallback(),
                        errorWidget: (_, __, ___) => _fallback(),
                      )
                    : _fallback(),
              ),
            ),

            // Group info
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isDark ? Colors.white : AppTheme.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${group.memberIds.length} members',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      alignment: Alignment.center,
      child: Text(
        group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

