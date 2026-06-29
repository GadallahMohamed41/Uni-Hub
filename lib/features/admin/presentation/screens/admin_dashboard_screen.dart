// ignore_for_file: deprecated_member_use
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:project_test2/core/theme/admin_theme_tokens.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/theme/theme_provider.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
import 'package:project_test2/features/home/presentation/screens/post_detail_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';

import 'package:image_picker/image_picker.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/core/widgets/image_detail_screen.dart';
import 'package:project_test2/core/widgets/custom_confirm_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Mock data models (static demo cards always visible in the Pending tab)
// ─────────────────────────────────────────────────────────────────────────────

enum _MockType { mention, question }

class _MockRequest {
  final String id;
  final String userName;
  final String userInitials;
  final Color avatarColor;
  final String? roleBadge;
  final String timeAgo;
  final _MockType type;
  // mention type
  final List<String> mentions;
  // question type
  final String? questionText;
  // optional image
  final String? imageUrl;

  const _MockRequest({
    required this.id,
    required this.userName,
    required this.userInitials,
    required this.avatarColor,
    this.roleBadge,
    required this.timeAgo,
    required this.type,
    this.mentions = const [],
    this.questionText,
    // ignore: unused_element_parameter — kept for image posts from Firestore
    this.imageUrl,
  });
}

const _mockToday = [
  _MockRequest(
    id: 'mock_1',
    userName: 'Eng Mohamed',
    userInitials: 'EM',
    avatarColor: Color(0xFF4D6BF5),
    roleBadge: 'Engineer',
    timeAgo: '7h ago',
    type: _MockType.mention,
    mentions: ['@Gadallah Mohamed', '@Essam Mohamed', '@Mohamed'],
  ),
  _MockRequest(
    id: 'mock_2',
    userName: 'Eng Mohamed',
    userInitials: 'EM',
    avatarColor: Color(0xFF4D6BF5),
    roleBadge: 'Engineer',
    timeAgo: '13h ago',
    type: _MockType.mention,
    mentions: ['@Gadallah Mohamed', '@Essam Mohamed'],
  ),
];

const _mockOlder = [
  _MockRequest(
    id: 'mock_3',
    userName: 'Gadallah Mohamed',
    userInitials: 'GM',
    avatarColor: Color(0xFF10B981),
    timeAgo: '1 month ago',
    type: _MockType.question,
    questionText: 'Can I transfer to another department? What are the requirements?',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Root screen widget
// ─────────────────────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminDashboardScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _activeTab = 0;
  final Set<String> _selected = {};
  final Set<String> _removedMockIds = {};  // cards dismissed after action
  int _rejectedMockCount = 0;              // feeds the stats tile
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTabIndex.clamp(0, 2);
    _activeTab = idx;
    _tabController = TabController(length: 3, vsync: this, initialIndex: idx)
      ..addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {
            _activeTab = _tabController.index;
            _selected.clear();
          });
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      final allIds = [..._mockToday, ..._mockOlder]
          .where((e) => !_removedMockIds.contains(e.id))
          .map((e) => e.id);
      _selected.addAll(allIds);
    });
  }

  /// Called by a mock card when the admin approves or rejects it.
  void _onMockCardAction(String id, {required bool approved}) {
    setState(() {
      _removedMockIds.add(id);
      _selected.remove(id);
      if (!approved) _rejectedMockCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tok = AdminTokens.of(context);

    return Scaffold(
      backgroundColor: tok.bgPrimary,
      body: Stack(
        children: [
          Column(
            children: [
              // ── Sticky header ─────────────────────────────────────────────
              _AdminHeader(
                tok: tok,
                activeTab: _activeTab,
                onTabChanged: (i) {
                  setState(() => _activeTab = i);
                  _tabController.animateTo(i);
                },
                searchCtrl: _searchCtrl,
                pendingCount:
                    (_mockToday.length + _mockOlder.length) -
                    _removedMockIds.length,
              ),

              // ── Quick stats row ───────────────────────────────────────────
              _StatsRow(
                tok: tok,
                removedMockCount: _removedMockIds.length,
                rejectedMockCount: _rejectedMockCount,
              ),

              // ── Tab body ──────────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _PendingTab(
                      tok: tok,
                      selected: _selected,
                      removedIds: _removedMockIds,
                      onToggleSelect: _toggleSelect,
                      onSelectAll: _selectAll,
                      onCardAction: _onMockCardAction,
                    ),
                    _ApprovedTab(tok: tok),
                    _SchedulesTab(tok: tok),
                  ],
                ),
              ),
            ],
          ),

          // ── Bulk action bar (slides up when items selected) ───────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BulkActionBar(
              tok: tok,
              count: _selected.length,
              onClear: () => setState(() => _selected.clear()),
              onApprove: () {
                final ids = _selected.toList();
                setState(() {
                  for (final id in ids) {
                    _onMockCardAction(id, approved: true);
                  }
                });
                AppSnackBar.showSuccess(context, '${ids.length} item${ids.length == 1 ? '' : 's'} approved');
              },
              onReject: () {
                final ids = _selected.toList();
                setState(() {
                  for (final id in ids) {
                    _onMockCardAction(id, approved: false);
                  }
                });
                AppSnackBar.showError(context, '${ids.length} item${ids.length == 1 ? '' : 's'} rejected');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky header
// ─────────────────────────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  final AdminTokens tok;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final TextEditingController searchCtrl;
  final int pendingCount;

  const _AdminHeader({
    required this.tok,
    required this.activeTab,
    required this.onTabChanged,
    required this.searchCtrl,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: tok.bgHeader,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 14),
      child: Column(
        children: [
          // Row 1 — back arrow / title / theme toggle / avatar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
              const Expanded(
                child: Text(
                  'Admin Dashboard',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Theme toggle
              GestureDetector(
                onTap: () => context.read<ThemeProvider>().toggleTheme(),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tok.headerOverlay,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Admin avatar
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tok.headerOverlay,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: const Center(
                  child: Text(
                    'AD',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2 — search bar (transparent fill)
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: tok.headerOverlay,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.tune_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search requests or names',
                      hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.search, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Row 3 — segmented pill tabs
          _SegmentedTabs(
            tok: tok,
            activeTab: activeTab,
            onTabChanged: onTabChanged,
            pendingCount: pendingCount,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented pill tabs
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  final AdminTokens tok;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final int pendingCount;

  const _SegmentedTabs({
    required this.tok,
    required this.activeTab,
    required this.onTabChanged,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    const labels = ['Pending', 'Approved', 'Schedules'];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List.generate(3, (i) {
          final isActive = activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTabChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xEEFFFFFF), Color(0xFFF0F3FF)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        )
                      : null,
                  color: isActive ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        color: isActive
                            ? tok.accentPrimary
                            : Colors.white.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    // badge on Pending tab
                    if (i == 0 && pendingCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isActive
                              ? tok.accentPrimary
                              : Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AdminTokens tok;
  final int removedMockCount;
  final int rejectedMockCount;

  const _StatsRow({
    required this.tok,
    required this.removedMockCount,
    required this.rejectedMockCount,
  });

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();

    return StreamBuilder<List<PostModel>>(
      stream: postsProvider.getPendingPostsStream(),
      builder: (context, snap) {
        final mockTotal = _mockToday.length + _mockOlder.length;
        final pending =
            (snap.data?.length ?? 0) + mockTotal - removedMockCount;
        final approved = postsProvider.posts.length;

        return Container(
          color: tok.bgPrimary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _StatTile(tok: tok, label: 'Pending', value: pending.clamp(0, 9999)),
              const SizedBox(width: 8),
              _StatTile(tok: tok, label: 'Approved', value: approved),
              const SizedBox(width: 8),
              _StatTile(tok: tok, label: 'Rejected', value: rejectedMockCount),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final AdminTokens tok;
  final String label;
  final int value;

  const _StatTile({required this.tok, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: tok.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tok.borderDefault, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: tok.textTertiary,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 19,
                color: tok.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending tab
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTab extends StatelessWidget {
  final AdminTokens tok;
  final Set<String> selected;
  final Set<String> removedIds;
  final ValueChanged<String> onToggleSelect;
  final VoidCallback onSelectAll;
  /// Called with (id, approved:true/false) when a card is actioned.
  final void Function(String id, {required bool approved}) onCardAction;

  const _PendingTab({
    required this.tok,
    required this.selected,
    required this.removedIds,
    required this.onToggleSelect,
    required this.onSelectAll,
    required this.onCardAction,
  });

  @override
  Widget build(BuildContext context) {
    // Filter out already-actioned cards
    final todayItems =
        _mockToday.where((e) => !removedIds.contains(e.id)).toList();
    final olderItems =
        _mockOlder.where((e) => !removedIds.contains(e.id)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── Section: اليوم ─────────────────────────────────────────────────
        if (todayItems.isNotEmpty) ...[
          _SectionHeader(
            tok: tok,
            label: 'Today',
            trailing: GestureDetector(
              onTap: onSelectAll,
              child: Text(
                'Select all',
                style: TextStyle(
                  fontSize: 12,
                  color: tok.accentPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...todayItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PendingCard(
                  key: ValueKey(item.id),
                  tok: tok,
                  item: item,
                  isSelected: selected.contains(item.id),
                  onToggleSelect: () => onToggleSelect(item.id),
                  onAction: onCardAction,
                ),
              )),
          const SizedBox(height: 12),
        ],

        // ── Section: من فترة ───────────────────────────────────────────────
        if (olderItems.isNotEmpty) ...[
          _SectionHeader(tok: tok, label: 'Earlier'),
          const SizedBox(height: 8),
          ...olderItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PendingCard(
                  key: ValueKey(item.id),
                  tok: tok,
                  item: item,
                  isSelected: selected.contains(item.id),
                  onToggleSelect: () => onToggleSelect(item.id),
                  onAction: onCardAction,
                ),
              )),
          const SizedBox(height: 12),
        ],

        // empty state when all mocks are gone
        if (todayItems.isEmpty && olderItems.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                'No pending requests',
                style: TextStyle(color: tok.textTertiary, fontSize: 13),
              ),
            ),
          ),

        // ── Live Firestore pending posts (below mock data) ─────────────────
        _LivePendingList(tok: tok),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final AdminTokens tok;
  final String label;
  final Widget? trailing;

  const _SectionHeader({required this.tok, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: tok.textTertiary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual pending card (mock)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingCard extends StatefulWidget {
  final AdminTokens tok;
  final _MockRequest item;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final void Function(String id, {required bool approved}) onAction;

  const _PendingCard({
    super.key,
    required this.tok,
    required this.item,
    required this.isSelected,
    required this.onToggleSelect,
    required this.onAction,
  });

  @override
  State<_PendingCard> createState() => _PendingCardState();
}

class _PendingCardState extends State<_PendingCard>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;

  void _showOverflowMenu(BuildContext context) {
    final tok = widget.tok;
    showModalBottomSheet(
      context: context,
      backgroundColor: tok.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _OverflowBottomSheet(tok: tok),
    );
  }

  void _quickApprove() {
    if (_dismissed) return;
    _dismissed = true;
    AppSnackBar.showSuccess(context, 'Approved ✓');
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) widget.onAction(widget.item.id, approved: true);
    });
  }

  void _quickReject() {
    if (_dismissed) return;
    _dismissed = true;
    AppSnackBar.showError(context, 'Rejected ✗');
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) widget.onAction(widget.item.id, approved: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tok = widget.tok;
    final item = widget.item;
    final accentColor =
        item.type == _MockType.mention ? tok.accentMention : tok.accentQuestion;

    return Slidable(
      key: ValueKey(item.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _quickApprove(),
            backgroundColor: tok.accentSuccess,
            foregroundColor: Colors.white,
            icon: Icons.check_rounded,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _quickReject(),
            backgroundColor: tok.accentDanger,
            foregroundColor: Colors.white,
            icon: Icons.close_rounded,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tok.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tok.borderDefault, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 4px accent bar
              Container(width: 4, color: accentColor),

              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Checkbox
                          GestureDetector(
                            onTap: widget.onToggleSelect,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: widget.isSelected
                                    ? tok.accentPrimary
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: widget.isSelected
                                      ? tok.accentPrimary
                                      : tok.textTertiary,
                                  width: 1.5,
                                ),
                              ),
                              child: widget.isSelected
                                  ? const Icon(Icons.check,
                                      size: 11, color: Colors.white)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Avatar
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: item.avatarColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: tok.bgSurface, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                item.userInitials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Name + badge + timestamp
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.userName,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: tok.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (item.roleBadge != null) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tok.mentionChipBg,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.roleBadge!,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w400,
                                            color: tok.mentionChipText,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.timeAgo,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tok.textTertiary,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Three-dot menu
                          GestureDetector(
                            onTap: () => _showOverflowMenu(context),
                            child: Icon(Icons.more_horiz,
                                color: tok.textSecondary, size: 20),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Content area
                      if (item.type == _MockType.mention)
                        _MentionChips(tok: tok, mentions: item.mentions)
                      else if (item.type == _MockType.question &&
                          item.questionText != null)
                        _QuotedBlock(tok: tok, text: item.questionText!),

                      // Optional image
                      if (item.imageUrl != null) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: item.imageUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 160,
                              color: tok.borderDefault,
                            ),
                            errorWidget: (_, __, ___) => Container(
                              height: 160,
                              color: tok.borderDefault,
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: tok.textTertiary),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Footer buttons
                      Row(
                        children: [
                          // Reject — icon-only square
                          GestureDetector(
                            onTap: _quickReject,
                            child: Container(
                              width: 38,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: tok.accentDanger, width: 1),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: tok.accentDanger, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Approve — wide pill
                          Expanded(
                            child: GestureDetector(
                              onTap: _quickApprove,
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: tok.accentSuccess,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'اعتماد',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mention chips
// ─────────────────────────────────────────────────────────────────────────────

class _MentionChips extends StatelessWidget {
  final AdminTokens tok;
  final List<String> mentions;

  const _MentionChips({required this.tok, required this.mentions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: mentions
          .map((m) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tok.mentionChipBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  m,
                  style: TextStyle(
                    fontSize: 12,
                    color: tok.mentionChipText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quoted text block (question type)
// ─────────────────────────────────────────────────────────────────────────────

class _QuotedBlock extends StatelessWidget {
  final AdminTokens tok;
  final String text;
  const _QuotedBlock({required this.tok, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tok.quoteBg,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          left: BorderSide(color: tok.accentQuestion, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      child: Text(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 13,
          color: tok.textPrimary,
          height: 1.6,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Three-dot overflow bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OverflowBottomSheet extends StatelessWidget {
  final AdminTokens tok;

  const _OverflowBottomSheet({required this.tok});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.person_outline_rounded, 'View full profile'),
      (Icons.article_outlined, 'View original post'),
      (Icons.volume_off_outlined, 'Mute user'),
    ];

    return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tok.borderDefault,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ...items.map((item) => ListTile(
                    leading: Icon(item.$1, color: tok.textSecondary, size: 20),
                    title: Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 14,
                        color: tok.textPrimary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    onTap: () => Navigator.pop(context),
                  )),
            ],
          ),
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bulk action bar
// ─────────────────────────────────────────────────────────────────────────────

class _BulkActionBar extends StatelessWidget {
  final AdminTokens tok;
  final int count;
  final VoidCallback onClear;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _BulkActionBar({
    required this.tok,
    required this.count,
    required this.onClear,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: count > 0 ? Offset.zero : const Offset(0, 1),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: count > 0 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: tok.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tok.borderDefault, width: 1),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close_rounded,
                    color: tok.textSecondary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count item${count == 1 ? '' : 's'} selected',
                  style: TextStyle(
                    fontSize: 13,
                    color: tok.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Reject all
              GestureDetector(
                onTap: onReject,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tok.accentDanger, width: 1),
                  ),
                  child: Text(
                    'Reject',
                    style: TextStyle(
                        fontSize: 13,
                        color: tok.accentDanger,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Approve all
              GestureDetector(
                onTap: onApprove,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: tok.accentSuccess,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Approve',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Firestore pending posts (wired to real backend)
// ─────────────────────────────────────────────────────────────────────────────

class _LivePendingList extends StatelessWidget {
  final AdminTokens tok;

  const _LivePendingList({required this.tok});

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();

    return StreamBuilder<List<PostModel>>(
      stream: postsProvider.getPendingPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: tok.accentPrimary),
            ),
          );
        }

        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Live requests',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: tok.textTertiary,
                ),
              ),
            ),
            ...posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LivePostCard(tok: tok, post: post),
                )),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Firestore card (styled with tokens, keeps original logic)
// ─────────────────────────────────────────────────────────────────────────────

class _LivePostCard extends StatelessWidget {
  final AdminTokens tok;
  final PostModel post;

  const _LivePostCard({required this.tok, required this.post});

  @override
  Widget build(BuildContext context) {
    // Assign a consistent color per user ID
    final avatarColors = [
      const Color(0xFF4D6BF5),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
    ];
    final colorIdx =
        math.max(0, post.userId.hashCode % avatarColors.length).abs();
    final avatarColor = avatarColors[colorIdx];

    return Slidable(
      key: ValueKey(post.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              final adminId = context.read<AuthProvider>().userId;
              context
                  .read<PostsProvider>()
                  .updatePostStatus(post.id, 'approved', adminId: adminId);
            },
            backgroundColor: tok.accentSuccess,
            foregroundColor: Colors.white,
            icon: Icons.check_rounded,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              final adminId = context.read<AuthProvider>().userId;
              context
                  .read<PostsProvider>()
                  .updatePostStatus(post.id, 'rejected', adminId: adminId);
            },
            backgroundColor: tok.accentDanger,
            foregroundColor: Colors.white,
            icon: Icons.close_rounded,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tok.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tok.borderDefault, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: tok.accentMention),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      UserProfileScreen(userId: post.userId)),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: avatarColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: tok.bgSurface, width: 2),
                              ),
                              child: post.userAvatarUrl != null
                                  ? ClipOval(
                                      child: CachedNetworkImage(
                                        imageUrl: post.userAvatarUrl!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        post.userName.isNotEmpty
                                            ? post.userName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.userName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: tok.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  post.formattedTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: tok.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Post text
                      Text(
                        post.text,
                        style: TextStyle(
                          fontSize: 13,
                          color: tok.textPrimary,
                          height: 1.5,
                        ),
                      ),

                      if (post.imageUrl != null ||
                          post.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageDetailScreen(
                                imageUrl:
                                    post.imageUrl ?? post.imageUrls.first,
                                heroTag: 'admin_live_${post.id}',
                              ),
                            ),
                          ),
                          child: Hero(
                            tag: 'admin_live_${post.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: CachedNetworkImage(
                                imageUrl:
                                    post.imageUrl ?? post.imageUrls.first,
                                height: 160,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Footer
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await CustomConfirmDialog.show(
                                context,
                                title: 'Reject Post',
                                content:
                                    'Are you sure you want to reject this post?',
                                confirmLabel: 'Reject',
                                confirmColor: tok.accentDanger,
                                icon: Icons.close_rounded,
                                onConfirm: () {
                                  final adminId =
                                      context.read<AuthProvider>().userId;
                                  context
                                      .read<PostsProvider>()
                                      .updatePostStatus(post.id, 'rejected',
                                          adminId: adminId);
                                },
                              );
                            },
                            child: Container(
                              width: 38,
                              height: 36,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: tok.accentDanger, width: 1),
                              ),
                              child: Icon(Icons.close_rounded,
                                  color: tok.accentDanger, size: 18),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await CustomConfirmDialog.show(
                                  context,
                                  title: 'Approve Post',
                                  content:
                                      'Are you sure you want to approve this post?',
                                  confirmLabel: 'Approve',
                                  confirmColor: tok.accentSuccess,
                                  icon: Icons.check_circle_outline_rounded,
                                  onConfirm: () {
                                    final adminId =
                                        context.read<AuthProvider>().userId;
                                    context
                                        .read<PostsProvider>()
                                        .updatePostStatus(post.id, 'approved',
                                            adminId: adminId);
                                  },
                                );
                              },
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: tok.accentSuccess,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.check_rounded,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      'Approve',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Approved tab (re-styled, logic unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _ApprovedTab extends StatelessWidget {
  final AdminTokens tok;

  const _ApprovedTab({required this.tok});

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();

    if (postsProvider.posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 56, color: tok.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No approved posts',
              style: TextStyle(color: tok.textSecondary, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: postsProvider.posts.length,
      itemBuilder: (context, index) {
        final post = postsProvider.posts[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ApprovedCard(tok: tok, post: post),
        );
      },
    );
  }
}

class _ApprovedCard extends StatelessWidget {
  final AdminTokens tok;
  final PostModel post;

  const _ApprovedCard({required this.tok, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: tok.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tok.borderDefault, width: 1),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          UserProfileScreen(userId: post.userId)),
                ),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: tok.accentPrimary.withOpacity(0.2),
                  backgroundImage: post.userAvatarUrl != null
                      ? CachedNetworkImageProvider(post.userAvatarUrl!)
                      : null,
                  child: post.userAvatarUrl == null
                      ? Text(
                          post.userName.isNotEmpty
                              ? post.userName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              color: tok.accentPrimary,
                              fontWeight: FontWeight.w500),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: tok.textPrimary)),
                    Text(post.formattedTime,
                        style: TextStyle(
                            fontSize: 11, color: tok.textTertiary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PostDetailScreen(postId: post.id)),
                ),
                child: Icon(Icons.arrow_forward_ios_rounded,
                    color: tok.textTertiary, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(post.text,
              style: TextStyle(
                  fontSize: 13, color: tok.textPrimary, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () async {
                  await CustomConfirmDialog.show(
                    context,
                    title: 'Delete Post',
                    content:
                        'Are you sure you want to delete this post?',
                    confirmLabel: 'Delete',
                    confirmColor: tok.accentDanger,
                    icon: Icons.delete_forever_rounded,
                    onConfirm: () {
                      context
                          .read<PostsProvider>()
                          .deletePost(post.id, post.imageUrls);
                    },
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.delete_outline,
                        color: tok.accentDanger, size: 16),
                    const SizedBox(width: 4),
                    Text('Delete',
                        style: TextStyle(
                            color: tok.accentDanger, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Schedules tab (logic unchanged, re-styled with tokens)
// ─────────────────────────────────────────────────────────────────────────────

class _SchedulesTab extends StatefulWidget {
  final AdminTokens tok;

  const _SchedulesTab({required this.tok});

  @override
  State<_SchedulesTab> createState() => _SchedulesTabState();
}

class _SchedulesTabState extends State<_SchedulesTab> {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedLevel;
  bool _isUploading = false;

  final Map<String, String> _universities = {
    'Industrial and Energy Technology': 'industrial_energy_technology',
    'College of Applied Health Sciences': 'applied_health_sciences',
  };
  final Map<String, List<Map<String, String>>> _departmentsByUniversity = {
    'industrial_energy_technology': [
      {'label': 'تكنولوجيا المعلومات', 'key': 'it'},
      {'label': 'أجهزه', 'key': 'devices'},
      {'label': 'شبكات', 'key': 'networks'},
      {'label': 'تصنيع غذائي', 'key': 'food_industry'},
    ],
    'applied_health_sciences': [],
  };
  final Map<String, String> _levels = {
    'الفرقه الاولى': 'level1',
    'الفرقه الثانيه': 'level2',
    'الفرقه الثالثه': 'level3',
    'الفرقه الرابعه': 'level4',
  };

  Future<void> _uploadSchedule() async {
    if (_selectedUniversity == null ||
        _selectedDepartment == null ||
        _selectedLevel == null) {
      AppSnackBar.showInfo(
          context, 'Please select university, department and level');
      return;
    }
    final adminId = context.read<AuthProvider>().userId;
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await _storageService.uploadLectureScheduleHierarchical(
        bytes,
        _selectedUniversity!,
        _selectedDepartment!,
        _selectedLevel!,
      );
      await _firestoreService.upsertScheduleMeta(
        universityKey: _selectedUniversity!,
        departmentKey: _selectedDepartment!,
        levelKey: _selectedLevel!,
        imageUrl: url,
      );
      if (adminId != null) {
        try {
          await _firestoreService.notifyScheduleUploaded(
            fromUserId: adminId,
            universityKey: _selectedUniversity!,
            departmentKey: _selectedDepartment!,
            levelKey: _selectedLevel!,
            imageUrl: url,
          );
        } catch (_) {}
      }
      if (mounted) AppSnackBar.showSuccess(context, 'Schedule uploaded!');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteSchedule() async {
    if (_selectedUniversity == null ||
        _selectedDepartment == null ||
        _selectedLevel == null) {
      AppSnackBar.showInfo(
          context, 'Please select university, department and level');
      return;
    }
    await CustomConfirmDialog.show(
      context,
      title: 'Delete Schedule',
      content: 'Are you sure you want to delete this schedule?',
      confirmLabel: 'Delete',
      confirmColor: widget.tok.accentDanger,
      icon: Icons.delete_outline_rounded,
      onConfirm: () async {
        try {
          await _firestoreService.deleteSchedule(
            universityKey: _selectedUniversity!,
            departmentKey: _selectedDepartment!,
            levelKey: _selectedLevel!,
          );
          if (mounted) AppSnackBar.showSuccess(context, 'Schedule deleted');
        } catch (e) {
          if (mounted) AppSnackBar.showError(context, 'Failed to delete: $e');
        }
      },
    );
  }

  InputDecoration _dropdownDeco(String label) {
    final tok = widget.tok;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: tok.textSecondary, fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tok.borderDefault),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tok.borderDefault),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: tok.accentPrimary),
      ),
      filled: true,
      fillColor: tok.bgSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tok = widget.tok;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // University dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: tok.textPrimary, fontSize: 14),
            dropdownColor: tok.bgSurface,
            decoration: _dropdownDeco('Select University'),
            value: _selectedUniversity,
            items: _universities.entries
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedUniversity = v;
              _selectedDepartment = null;
            }),
          ),
          const SizedBox(height: 14),

          // Department dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: tok.textPrimary, fontSize: 14),
            dropdownColor: tok.bgSurface,
            decoration: _dropdownDeco('Select Department'),
            value: _selectedDepartment,
            items: (_selectedUniversity == null
                    ? <DropdownMenuItem<String>>[]
                    : _departmentsByUniversity[_selectedUniversity!]!
                        .map((m) => DropdownMenuItem(
                              value: m['key'],
                              child: Text(m['label']!,
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList()),
            onChanged: (v) => setState(() => _selectedDepartment = v),
          ),
          const SizedBox(height: 14),

          // Level dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: tok.textPrimary, fontSize: 14),
            dropdownColor: tok.bgSurface,
            decoration: _dropdownDeco('Select Level'),
            value: _selectedLevel,
            items: _levels.entries
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedLevel = v),
          ),
          const SizedBox(height: 20),

          // Preview existing schedule
          if (_selectedUniversity != null &&
              _selectedDepartment != null &&
              _selectedLevel != null)
            StreamBuilder<Map<String, dynamic>?>(
              stream: _firestoreService.getScheduleMetaStream(
                universityKey: _selectedUniversity!,
                departmentKey: _selectedDepartment!,
                levelKey: _selectedLevel!,
              ),
              builder: (context, snap) {
                final url = snap.data?['imageUrl'] as String?;
                if (url == null || url.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Current schedule preview',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: tok.textPrimary,
                            fontSize: 13)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ImageDetailScreen(
                              imageUrl: url,
                              heroTag: 'schedule_preview_$url'),
                        ),
                      ),
                      child: Hero(
                        tag: 'schedule_preview_$url',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                              imageUrl: url, height: 180, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _deleteSchedule,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: tok.accentDanger, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline,
                                color: tok.accentDanger, size: 18),
                            const SizedBox(width: 6),
                            Text('Delete schedule',
                                style: TextStyle(
                                    color: tok.accentDanger, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),

          // Upload button
          GestureDetector(
            onTap: _isUploading ? null : _uploadSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _isUploading
                    ? tok.accentPrimary.withOpacity(0.5)
                    : tok.accentPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  else
                    const Icon(Icons.upload_file,
                        color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isUploading ? 'Uploading...' : 'Upload Schedule Image',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
