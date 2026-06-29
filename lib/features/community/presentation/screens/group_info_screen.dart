import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_member_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/group_invite_section.dart';
import 'package:project_test2/features/community/presentation/screens/admin_requests_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_media_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_settings_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_chat_screen.dart';
import 'package:project_test2/features/community/data/repositories/group_join_request_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_join_request_entity.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GroupInfoScreen
// ─────────────────────────────────────────────────────────────────────────────
class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _repo = GroupRepositoryImpl();
  GroupEntity? _group;
  List<GroupMemberEntity> _members = [];

  // ── constants ────────────────────────────────────────────────────────────
  static const Color _headerBlue = Color(0xFF1565C0);
  static const Color _bodyGray   = Color(0xFFF2F2F7);
  static const Color _redLeave   = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _repo.watchMembers(widget.groupId).listen((m) {
      if (mounted) setState(() => _members = m);
    });
    _repo.watchGroup(widget.groupId).listen((group) {
      if (mounted && group != null) setState(() => _group = group);
    });
    _repo.getGroup(widget.groupId).then((g) {
      if (mounted && g != null) setState(() => _group = g);
    });
  }

  // ── helpers ──────────────────────────────────────────────────────────────
  int get _onlineCount => _members.where((m) => m.isOnline).length;

  // media count (placeholder – real count would come from repo)
  int get _mediaCount => 0;

  @override
  Widget build(BuildContext context) {
    final g = _group;

    if (g == null) {
      return Scaffold(
        backgroundColor: _bodyGray,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = g.isAdmin(widget.currentUserId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : _bodyGray,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ────────────────────────── HEADER ────────────────────────
                _buildHeader(context, g, isAdmin),

                const SizedBox(height: 8),

                // ─────────────────── DESCRIPTION & REQUESTS CARD ───────────
                if (g.description.isNotEmpty || isAdmin) ...[
                  _buildInfoCard(context, g, isAdmin),
                  const SizedBox(height: 6),
                ],

                // ─────────────────── INVITE SECTION (admin) ───────────────
                if (g.inviteLink != null && isAdmin) ...[
                  GroupInviteSection(group: g),
                  const SizedBox(height: 6),
                ],

                // ─────────────────── MEDIA CARD ───────────────────────────
                _buildMediaCard(context, g),
                const SizedBox(height: 10),

                // ─────────────────── MEMBERS SECTION ──────────────────────
                _buildMembersLabel(isAdmin, g),
                const SizedBox(height: 4),
                _buildMembersCard(context, g, isAdmin),
                const SizedBox(height: 10),

                // ─────────────────── LEAVE GROUP ──────────────────────────
                _buildLeaveCard(context, g),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, GroupEntity g, bool isAdmin) {
    return Container(
      width: double.infinity,
      color: _headerBlue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── nav row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // Back button
                _CircleIconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                // Search
                _CircleIconBtn(
                  icon: Icons.search_rounded,
                  onTap: () {},
                ),
                const SizedBox(width: 6),
                // More options
                _CircleIconBtn(
                  icon: Icons.more_vert_rounded,
                  onTap: () => _showMoreMenu(context, g, isAdmin),
                ),
              ],
            ),
          ),

          // ── avatar + name + description row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                _GroupHeaderAvatar(
                  imageUrl: g.imageUrl,
                  groupName: g.name,
                ),
                const SizedBox(width: 14),
                // Name + description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        g.description.isNotEmpty
                            ? g.description
                            : 'No description',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── stats bar ──
          _buildStatsBar(),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCell(label: 'Members', value: '${_members.length}'),
            _VerticalDivider(),
            _StatCell(label: 'Online', value: '$_onlineCount'),
            _VerticalDivider(),
            _StatCell(label: 'Media', value: '$_mediaCount'),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DESCRIPTION / INFO CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildInfoCard(BuildContext context, GroupEntity g, bool isAdmin) {
    return _WhiteCard(
      child: Column(
        children: [
          // Description row
          if (g.description.isNotEmpty)
            _InfoTile(
              iconBox: _IconBox(
                icon: Icons.info_outline_rounded,
                color: _headerBlue,
              ),
              title: g.description,
              subtitle: null,
              trailing: null,
              onTap: null,
            ),

          if (isAdmin) ...[
            if (g.description.isNotEmpty) const _ThinDivider(),
            // Pending requests row
            StreamBuilder<List<GroupJoinRequestEntity>>(
              stream: GroupJoinRequestRepositoryImpl().watchPendingRequests(widget.groupId),
              builder: (context, snapshot) {
                final pendingRequests = snapshot.data ?? [];
                final count = pendingRequests.length;
                return _InfoTile(
                  iconBox: _IconBox(
                    icon: Icons.pending_actions_rounded,
                    color: Colors.orange,
                  ),
                  title: 'Pending Join Requests',
                  subtitle: null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626), // Premium red notification badge
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    ],
                  ),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminRequestsScreen(groupId: widget.groupId),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEDIA CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMediaCard(BuildContext context, GroupEntity g) {
    return _WhiteCard(
      child: _InfoTile(
        iconBox: _IconBox(
          icon: Icons.photo_library_outlined,
          color: _headerBlue,
        ),
        title: 'Media, Links & Docs',
        subtitle: 'Shared files and media',
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupMediaScreen(groupId: widget.groupId),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEMBERS LABEL
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMembersLabel(bool isAdmin, GroupEntity g) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1565C0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '${_members.length} Members',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primaryColor,
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (isAdmin)
            GestureDetector(
              onTap: () => _showAddMemberSheet(context, g),
              child: Row(
                children: [
                  Icon(Icons.person_add_rounded, size: 16, color: primaryColor),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 13,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MEMBERS CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMembersCard(BuildContext context, GroupEntity g, bool isAdmin) {
    return _WhiteCard(
      child: Column(
        children: _members.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;
          final isOwner = m.role == GroupRole.owner;
          final isAdminRole = m.role == GroupRole.admin;

          return Column(
            children: [
              if (idx != 0) const _ThinDivider(),
              _MemberRow(
                member: m,
                isOwner: isOwner,
                isAdminRole: isAdminRole,
                canManage: isAdmin && m.userId != widget.currentUserId,
                onRemove: () => _removeMember(m),
                onPromote: () => _promoteAdmin(m),
                onDemote: () => _demoteAdmin(m),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // LEAVE GROUP CARD
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLeaveCard(BuildContext context, GroupEntity g) {
    return _WhiteCard(
      child: _InfoTile(
        iconBox: _IconBox(
          icon: Icons.logout_rounded,
          color: _redLeave,
        ),
        title: 'Leave Group',
        titleColor: _redLeave,
        subtitle: null,
        trailing: null,
        onTap: () => _leaveGroup(context, g),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────────────────────────────────────
  void _showMoreMenu(BuildContext context, GroupEntity g, bool isAdmin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.settings_rounded, color: AppTheme.primary),
                title: const Text('Group Settings'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupSettingsScreen(
                        group: g,
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Close'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemberSheet(BuildContext context, GroupEntity g) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_add_rounded, size: 48, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text('Add Members',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Share the invite link with your friends to allow them to join the group.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy Invite Link',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  if (g.inviteLink != null) {
                    Clipboard.setData(ClipboardData(text: g.inviteLink!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite link copied!')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeMember(GroupMemberEntity m) async {
    final ok = await _confirm(context, 'Remove ${m.name} from group?');
    if (!ok) return;
    try {
      await _repo.removeMember(
        groupId: widget.groupId,
        targetUserId: m.userId,
        actorId: widget.currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Removed ${m.name} successfully.'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      debugPrint('[GroupInfoScreen] Error removing member: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to remove member: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _promoteAdmin(GroupMemberEntity m) async {
    try {
      await _repo.promoteToAdmin(
        groupId: widget.groupId,
        targetUserId: m.userId,
        actorId: widget.currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Promoted ${m.name} to Admin.'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to promote: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _demoteAdmin(GroupMemberEntity m) async {
    try {
      await _repo.demoteFromAdmin(
        groupId: widget.groupId,
        targetUserId: m.userId,
        actorId: widget.currentUserId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Removed ${m.name} from Admins.'),
              backgroundColor: AppTheme.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to demote: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _leaveGroup(BuildContext context, GroupEntity g) async {
    if (g.isOwner(widget.currentUserId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transfer ownership before leaving.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    final ok = await _confirm(context, 'Leave this group?');
    if (!ok) return;
    try {
      GroupChatScreen.leavingGroupIds.add(widget.groupId);
      await _repo.leaveGroup(
          groupId: widget.groupId, userId: widget.currentUserId);
      if (context.mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      GroupChatScreen.leavingGroupIds.remove(widget.groupId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to leave group: $e'),
              backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<bool> _confirm(BuildContext context, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirm'),
            content: Text(message),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Circular semi-transparent back/icon button used in the header nav row.
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.15),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Circular group avatar shown in the header (left side of name/description).
class _GroupHeaderAvatar extends StatelessWidget {
  final String? imageUrl;
  final String groupName;

  const _GroupHeaderAvatar({
    required this.imageUrl,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final letter =
        groupName.isNotEmpty ? groupName[0].toUpperCase() : '?';

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _LetterPlaceholder(letter: letter),
                errorWidget: (_, __, ___) => _LetterPlaceholder(letter: letter),
              )
            : _LetterPlaceholder(letter: letter),
      ),
    );
  }
}

class _LetterPlaceholder extends StatelessWidget {
  final String letter;
  const _LetterPlaceholder({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A single stat cell in the stats bar.
class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thin vertical white divider between stat cells.
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

/// White rounded card container.
class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Thin horizontal divider used inside cards.
class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey.withValues(alpha: 0.12),
      indent: 16,
      endIndent: 16,
    );
  }
}

/// Blue / colored rounded icon box (9px radius).
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// Generic info tile row used inside cards.
class _InfoTile extends StatelessWidget {
  final Widget iconBox;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _InfoTile({
    required this.iconBox,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            iconBox,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// A member row inside the members card.
class _MemberRow extends StatelessWidget {
  final GroupMemberEntity member;
  final bool isOwner;
  final bool isAdminRole;
  final bool canManage;
  final VoidCallback? onRemove;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;

  const _MemberRow({
    required this.member,
    required this.isOwner,
    required this.isAdminRole,
    required this.canManage,
    this.onRemove,
    this.onPromote,
    this.onDemote,
  });

  static const Color _ownerBg = Color(0xFFEFF6FF);
  static const Color _ownerFg = Color(0xFF1D4ED8);
  static const Color _adminBg = Color(0xFFF0FDF4);
  static const Color _adminFg = Color(0xFF15803D);

  // Deterministic avatar color per member name
  static Color _avatarColor(String name) {
    const palette = [
      Color(0xFF1565C0),
      Color(0xFF7B3FC4),
      Color(0xFF0D7A5F),
      Color(0xFFB45309),
      Color(0xFF9B1C1C),
    ];
    if (name.isEmpty) return palette[0];
    int hash = 0;
    for (final ch in name.codeUnits) {
      hash = (hash * 31 + ch) & 0xFFFFFFFF;
    }
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial =
        member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    final avatarColor = _avatarColor(member.name);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor,
                child: member.avatarUrl != null &&
                        member.avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: member.avatarUrl!,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Text(initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          errorWidget: (_, __, ___) => Text(initial,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                        ),
                      )
                    : Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
              ),
              // Online dot
              if (member.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(width: 12),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (member.isOnline)
                      const Text(
                        '● Online',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF22C55E),
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else
                      const Text(
                        'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Role badge + optional manage popup
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                _Badge(
                  label: '👑 Owner',
                  bg: _ownerBg,
                  fg: _ownerFg,
                ),
              if (isAdminRole)
                _Badge(
                  label: '⭐ Admin',
                  bg: _adminBg,
                  fg: _adminFg,
                ),
              if (canManage && member.role != GroupRole.owner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: Colors.grey, size: 20),
                  onSelected: (val) {
                    if (val == 'remove') onRemove?.call();
                    if (val == 'promote') onPromote?.call();
                    if (val == 'demote') onDemote?.call();
                  },
                  itemBuilder: (_) => [
                    if (member.role == GroupRole.member)
                      const PopupMenuItem(
                        value: 'promote',
                        child: Row(children: [
                          Icon(Icons.admin_panel_settings_rounded,
                              color: Color(0xFF1565C0)),
                          SizedBox(width: 8),
                          Text('Make Admin'),
                        ]),
                      ),
                    if (member.role == GroupRole.admin)
                      const PopupMenuItem(
                        value: 'demote',
                        child: Row(children: [
                          Icon(Icons.person_rounded,
                              color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Remove Admin'),
                        ]),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(children: [
                        Icon(Icons.person_remove_rounded,
                            color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Text('Remove',
                            style:
                                TextStyle(color: Color(0xFFDC2626))),
                      ]),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small role/label badge pill.
class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Badge({
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
