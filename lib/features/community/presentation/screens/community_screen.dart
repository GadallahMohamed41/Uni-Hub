import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/features/community/domain/entities/community_entity.dart';
import 'package:project_test2/features/community/domain/entities/group_entity.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_event.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_state.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_event.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_state.dart';
import 'package:project_test2/features/community/presentation/screens/create_community_screen.dart';
import 'package:project_test2/features/community/presentation/screens/community_detail_screen.dart';
import 'package:project_test2/features/community/presentation/screens/create_group_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_chat_screen.dart';
import 'package:project_test2/features/community/data/repositories/community_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/data/repositories/group_invite_repository_impl.dart';
import 'package:project_test2/features/community/presentation/screens/join_request_screen.dart';
import 'package:project_test2/features/community/presentation/screens/community_join_request_screen.dart';
import 'package:project_test2/core/widgets/sticky_header_layout.dart';
/// Highly polished, production-ready "Communities and Groups" dashboard.
/// Fully adaptive to Light/Dark modes using Theme.of(context).colorScheme.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final CommunityListBloc _communityBloc;
  late final GroupsListBloc _groupsBloc;

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All' | 'Unread' | 'My Groups' | 'Admin'
  final Set<String> _autojoiningCommunityIds = {};

  @override
  void initState() {
    super.initState();
    _communityBloc = CommunityListBloc(repository: CommunityRepositoryImpl());
    _groupsBloc = GroupsListBloc(repository: GroupRepositoryImpl());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().currentUser?.uid;
      if (uid != null) {
        _communityBloc.add(CommunityListStarted(uid));
        _groupsBloc.add(GroupsListStarted(uid));
      }
    });
  }

  @override
  void dispose() {
    _communityBloc.close();
    _groupsBloc.close();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshData(String uid) {
    _communityBloc.add(CommunityListStarted(uid));
    _groupsBloc.add(GroupsListStarted(uid));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final me = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final myId = me?.uid ?? '';
    final auth = context.read<AuthProvider>();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _communityBloc),
        BlocProvider.value(value: _groupsBloc),
      ],
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        body: BlocConsumer<CommunityListBloc, CommunityListState>(
          listener: (context, communityState) {
            if (communityState is CommunityListLoaded && communityState.error != null) {
              final msg = communityState.error!;
              if (msg.toLowerCase().contains('already joined')) {
                AppSnackBar.showInfo(context, msg);
              } else {
                AppSnackBar.showError(context, msg);
              }
              _communityBloc.add(const CommunityListErrorCleared());
            }
          },
          builder: (context, communityState) {
            return BlocConsumer<GroupsListBloc, GroupsListState>(
              listener: (context, groupsState) {
                if (groupsState is GroupsListLoaded) {
                  // If the user belongs to a group inside a community but is not registered in that community
                  // (e.g., parent community membership write was skipped due to admin permission limits),
                  // auto-register the user to the community from their own side in the background.
                  final loadedCommunities = communityState is CommunityListLoaded
                      ? communityState.communities
                      : <CommunityEntity>[];
                  final loadedCommunityIds = loadedCommunities.map((c) => c.id).toSet();

                  for (final group in groupsState.groups) {
                    if (group.communityId != null && group.communityId!.isNotEmpty) {
                      if (!loadedCommunityIds.contains(group.communityId)) {
                        _autoJoinCommunity(
                          group.communityId!,
                          myId,
                          me?.name ?? 'User',
                          me?.avatarUrl,
                        );
                      }
                    }
                  }

                  if (groupsState.newlyCreatedGroup != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GroupChatScreen(
                          groupId: groupsState.newlyCreatedGroup!.id,
                          currentUserId: myId,
                          currentUserName: me?.name ?? 'User',
                          currentUserAvatarUrl: me?.avatarUrl,
                        ),
                      ),
                    );
                    _groupsBloc.add(const GroupsListNewlyCreatedCleared());
                  }
                  if (groupsState.error != null) {
                    final msg = groupsState.error!;
                    AppSnackBar.showError(context, msg);
                    _groupsBloc.add(const GroupsListErrorCleared());
                  }
                }
              },
              builder: (context, groupsState) {
                // Determine loading and error states
                final isLoading = (communityState is CommunityListLoading ||
                    communityState is CommunityListInitial ||
                    groupsState is GroupsListLoading ||
                    groupsState is GroupsListInitial);

                final hasError = (communityState is CommunityListError || groupsState is GroupsListError);
                final errorMessage = communityState is CommunityListError
                    ? (communityState).message
                    : (groupsState is GroupsListError ? (groupsState).message : 'An error occurred');

                if (isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (hasError) {
                  return _ErrorView(
                    message: errorMessage,
                    onRetry: () => _refreshData(myId),
                  );
                }

                // Retrieve communities and groups
                final communities = communityState is CommunityListLoaded ? communityState.communities : <CommunityEntity>[];
                final groups = groupsState is GroupsListLoaded ? groupsState.groups : <GroupEntity>[];

                // Filter lists based on Search & Chips
                final filteredCommunities = _getFilteredCommunities(communities, groups, myId);
                final filteredStandaloneGroups = _getFilteredStandaloneGroups(groups, myId);

                final isEmpty = filteredCommunities.isEmpty && filteredStandaloneGroups.isEmpty;

                return StickyHeaderLayout(
                  header: _CommunityHeader(
                    title: isArabic ? 'المجتمع' : 'Community',
                    searchController: _searchCtrl,
                    searchQuery: _searchQuery,
                    activeFilter: _activeFilter,
                    onSearchChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    onFilterChanged: (filter) {
                      setState(() => _activeFilter = filter);
                    },
                    onCreatePressed: () => _showAddOptions(context, myId, auth),
                  ),
                  body: RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      _refreshData(myId);
                      await Future.delayed(const Duration(milliseconds: 600));
                    },
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // 3 & 4 & 5. Communities List & Standalone Groups
                        if (isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyState(
                              icon: Icons.forum_outlined,
                              title: _searchQuery.isNotEmpty
                                  ? (isArabic ? 'لم يتم العثور على نتائج' : 'No results found')
                                  : (isArabic ? 'لا توجد مجتمعات بعد' : 'No communities yet'),
                              subtitle: _searchQuery.isNotEmpty
                                  ? (isArabic ? 'حاول البحث عن اسم آخر' : 'Try searching with a different term')
                                  : (isArabic ? 'أنشئ مجتمعًا جديدًا أو انضم إلى واحد' : 'Create a new community or join one'),
                            ),
                          )
                        else ...[
                          // Communities sliver
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final community = filteredCommunities[index];
                                final communityGroups = groups.where((g) => g.communityId == community.id).toList();

                                // Further filter community groups by search and filter chips
                                final displayGroups = communityGroups.where((g) {
                                  final matchesSearch = _searchQuery.isEmpty ||
                                      g.name.toLowerCase().contains(_searchQuery.toLowerCase());
                                  final matchesFilter = _activeFilter != 'Unread' || g.myUnread(myId) > 0;
                                  return matchesSearch && matchesFilter;
                                }).toList()
                                  ..sort((a, b) {
                                    // Announcement (main) group always appears first
                                    if (a.isAnnouncementOnly && !b.isAnnouncementOnly) return -1;
                                    if (!a.isAnnouncementOnly && b.isAnnouncementOnly) return 1;
                                    return 0;
                                  });

                                if (displayGroups.isEmpty && _activeFilter == 'Unread') {
                                  return const SizedBox.shrink();
                                }

                                return _CommunityExpansionCard(
                                  community: community,
                                  groups: displayGroups,
                                  currentUserId: myId,
                                  auth: auth,
                                  onCommunityTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CommunityDetailScreen(community: community),
                                    ),
                                  ),
                                );
                              },
                              childCount: filteredCommunities.length,
                            ),
                          ),

                          // Standalone groups section header
                          if (filteredStandaloneGroups.isNotEmpty && _activeFilter != 'Admin')
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                                child: Text(
                                  isArabic ? 'المثبتة' : 'PINNED',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white.withValues(alpha: 0.35) : colorScheme.onSurface.withValues(alpha: 0.4),
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ),

                          // Standalone groups list
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final group = filteredStandaloneGroups[index];
                                return _GroupSlidableTile(
                                  group: group,
                                  currentUserId: myId,
                                  auth: auth,
                                  isStandalone: true,
                                );
                              },
                              childCount: filteredStandaloneGroups.length,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 100)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ── Helper Filtering Methods ──────────────────────────────────────────────

  List<CommunityEntity> _getFilteredCommunities(List<CommunityEntity> communities, List<GroupEntity> groups, String myId) {
    if (_activeFilter == 'My Groups') {
      return []; // Only standalone groups
    }

    return communities.where((c) {
      // 1. Search Query filter
      final matchesSearch = _searchQuery.isEmpty ||
          c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.description.toLowerCase().contains(_searchQuery.toLowerCase());

      // 2. Chip Filter: Admin
      final matchesAdmin = _activeFilter != 'Admin' || c.isCreator(myId);

      // 3. Chip Filter: Unread
      bool matchesUnread = true;
      if (_activeFilter == 'Unread') {
        final communityGroups = groups.where((g) => g.communityId == c.id);
        matchesUnread = communityGroups.any((g) => g.myUnread(myId) > 0);
      }

      return matchesSearch && matchesAdmin && matchesUnread;
    }).toList();
  }

  List<GroupEntity> _getFilteredStandaloneGroups(List<GroupEntity> groups, String myId) {
    final standalone = groups.where((g) => g.communityId == null).toList();

    return standalone.where((g) {
      // 1. Search Query filter
      final matchesSearch = _searchQuery.isEmpty ||
          g.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          g.description.toLowerCase().contains(_searchQuery.toLowerCase());

      // 2. Chip Filters
      if (_activeFilter == 'Unread' && g.myUnread(myId) == 0) return false;
      if (_activeFilter == 'Admin' && !g.isAdmin(myId)) return false;

      return matchesSearch;
    }).toList();
  }

  void _autoJoinCommunity(String communityId, String userId, String userName, String? userAvatarUrl) async {
    if (_autojoiningCommunityIds.contains(communityId)) return;
    _autojoiningCommunityIds.add(communityId);

    try {
      final repo = CommunityRepositoryImpl();
      await repo.joinCommunity(
        communityId: communityId,
        userId: userId,
        userName: userName,
        userAvatarUrl: userAvatarUrl,
      );
      if (mounted) {
        _communityBloc.add(CommunityListStarted(userId));
      }
    } catch (e) {
      debugPrint('[CommunityScreen] Failed to auto-join community $communityId: $e');
    } finally {
      _autojoiningCommunityIds.remove(communityId);
    }
  }

  void _showAddOptions(BuildContext context, String myId, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOptionsSheet(
        myId: myId,
        auth: auth,
        communityBloc: _communityBloc,
        groupsBloc: _groupsBloc,
        parentContext: context,
      ),
    );
  }
}

// ── Widget 1: SliverAppBar (Collapsible Header) ──────────────────────────────

class _CommunityHeader extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final String searchQuery;
  final String activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onCreatePressed;

  const _CommunityHeader({
    required this.title,
    required this.searchController,
    required this.searchQuery,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final filters = [
      {'key': 'All', 'label': isArabic ? 'الكل' : 'All'},
      {'key': 'Unread', 'label': isArabic ? 'غير مقروء' : 'Unread'},
      {'key': 'My Groups', 'label': isArabic ? 'مجموعاتي' : 'My Groups'},
      {'key': 'Admin', 'label': isArabic ? 'المشرف' : 'Admin'},
    ];

    return Container(
      color: isDark ? const Color(0xFF0F1923) : theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Title & Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Row(
                    children: [
                      // Search icon button
                      IconButton(
                        icon: Icon(
                          Icons.search_rounded,
                          color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                          size: 22,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                      // Vertical dots menu
                      IconButton(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                          size: 22,
                        ),
                        onPressed: onCreatePressed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Row 2: Search Bar (pill shape)
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A2535) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: isDark ? Colors.white.withValues(alpha: 0.5) : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        onChanged: onSearchChanged,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: isDark ? Colors.white : theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: isArabic ? 'بحث...' : 'Search...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white.withValues(alpha: 0.6) : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Row 3: Filter Chips
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: filters.length,
                  itemBuilder: (context, index) {
                    final filter = filters[index];
                    final isSelected = activeFilter == filter['key'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => onFilterChanged(filter['key']!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2D6EF5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2D6EF5)
                                  : (isDark ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              filter['label']!,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white.withValues(alpha: 0.7) : theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widget 3: Community Section (Expandable Card - ExpansionTile) ───────────

class _CommunityExpansionCard extends StatefulWidget {
  final CommunityEntity community;
  final List<GroupEntity> groups;
  final String currentUserId;
  final AuthProvider auth;
  final VoidCallback onCommunityTap;

  const _CommunityExpansionCard({
    required this.community,
    required this.groups,
    required this.currentUserId,
    required this.auth,
    required this.onCommunityTap,
  });

  @override
  State<_CommunityExpansionCard> createState() => _CommunityExpansionCardState();
}

class _CommunityExpansionCardState extends State<_CommunityExpansionCard> {
  bool _isExpanded = false; // Closed by default

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Calculate unique members count
    final uniqueMembers = widget.groups.expand((g) => g.memberIds).toSet().length;
    final displayMemberCount = uniqueMembers;

    // Premium dynamic backgrounds
    final headerGradient = isDark
        ? LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.08),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.secondary.withValues(alpha: 0.01),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          color: isDark ? const Color(0xFF1A2535) : Colors.white,
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            initiallyExpanded: false,
            onExpansionChanged: (expanded) {
              setState(() {
                _isExpanded = expanded;
              });
            },
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            // Custom collapsible header with subtle tint gradient background
            title: Ink(
              decoration: BoxDecoration(
                gradient: headerGradient,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    // Rounded Square Community Avatar
                    _RoundedSquareAvatar(
                      imageUrl: widget.community.imageUrl,
                      name: widget.community.name,
                      size: 48,
                    ),
                    const SizedBox(width: 12),

                    // Info Column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.community.name,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              fontFamily: 'Tajawal',
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            isArabic ? '$displayMemberCount عضوًا' : '$displayMemberCount members',
                            style: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Expand/Collapse Indicator
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.55),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    // Action detail button
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onCommunityTap,
                    ),
                  ],
                ),
              ),
            ),
            trailing: const SizedBox.shrink(), // Overridden internally, handled manually
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: Row(
                  children: [
                    Text(
                      isArabic ? 'المجموعات' : 'Groups',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    // Blue pill "+ Add group" button
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CreateGroupScreen(
                              currentUserId: widget.currentUserId,
                              currentUserName: widget.auth.currentUser?.name ?? 'User',
                              currentUserAvatarUrl: widget.auth.currentUser?.avatarUrl,
                              communityId: widget.community.id,
                              onGroupCreated: (name, desc, memberIds, imageUrl, isPublic) async {
                                final scaffoldMessenger = ScaffoldMessenger.of(context);
                                try {
                                  final communityRepo = CommunityRepositoryImpl();
                                  await communityRepo.createGroupInCommunity(
                                    communityId: widget.community.id,
                                    name: name,
                                    description: desc,
                                    ownerId: widget.currentUserId,
                                    ownerName: widget.auth.currentUser?.name ?? 'User',
                                    ownerAvatarUrl: widget.auth.currentUser?.avatarUrl,
                                    imageUrl: imageUrl,
                                  );
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabic
                                            ? 'تم إنشاء المجموعة بنجاح'
                                            : 'Group created successfully',
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isArabic
                                            ? 'خطأ أثناء إنشاء المجموعة: $e'
                                            : 'Error creating group: $e',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6EF5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Add group',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      isArabic ? 'لا توجد مجموعات نشطة' : 'No active groups',
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.groups.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                  itemBuilder: (context, index) {
                    final group = widget.groups[index];
                    return _GroupSlidableTile(
                      group: group,
                      currentUserId: widget.currentUserId,
                      auth: widget.auth,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedSquareAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  const _RoundedSquareAvatar({
    required this.imageUrl,
    required this.name,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _fallback(),
          errorWidget: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'C',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.45,
        ),
      ),
    );
  }
}

// ── Widget 4 & 5: Slidable Group Tile & Swipe Actions ───────────────────────

class _GroupSlidableTile extends StatelessWidget {
  final GroupEntity group;
  final String currentUserId;
  final AuthProvider auth;
  final bool isStandalone;

  const _GroupSlidableTile({
    required this.group,
    required this.currentUserId,
    required this.auth,
    this.isStandalone = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final unread = group.myUnread(currentUserId);
    final hasUnread = unread > 0;

    final firstLetter = group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G';

    // Pick a distinct flat color per group based on name hash
    final avatarColors = [
      const Color(0xFF2D6EF5), // blue
      const Color(0xFF22C55E), // green
      const Color(0xFFA855F7), // purple
      const Color(0xFFF97316), // orange
      const Color(0xFFEF4444), // red
      const Color(0xFF06B6D4), // cyan
    ];
    final avatarColor = avatarColors[group.name.hashCode.abs() % avatarColors.length];

    Widget fallbackAvatar(String letter) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: avatarColor,
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }

    Widget avatar;
    final url = (group.imageUrl ?? '').trim();
    if (url.isNotEmpty) {
      avatar = ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 46,
          height: 46,
          fit: BoxFit.cover,
          placeholder: (_, __) => fallbackAvatar(firstLetter),
          errorWidget: (_, __, ___) => fallbackAvatar(firstLetter),
        ),
      );
    } else {
      avatar = fallbackAvatar(firstLetter);
    }

    Widget mainTile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2535) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupChatScreen(
                  groupId: group.id,
                  currentUserId: currentUserId,
                  currentUserName: auth.currentUser?.name ?? 'User',
                  currentUserAvatarUrl: auth.currentUser?.avatarUrl,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.isAnnouncementOnly
                              ? group.name
                                  .replaceAll(RegExp(r'\s*Announcements\s*', caseSensitive: false), '')
                                  .trim()
                              : group.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: isDark ? Colors.white : colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 14,
                              color: isDark ? Colors.white.withValues(alpha: 0.4) : colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isArabic ? '${group.memberIds.length} عضوًا' : '${group.memberIds.length} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white.withValues(alpha: 0.4) : colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasUnread) ...[
                        Container(
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B6BD4),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                        color: isDark ? Colors.white.withValues(alpha: 0.3) : colorScheme.onSurface.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Slidable(
      key: ValueKey(group.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.45,
        children: [
          SlidableAction(
            onPressed: (context) {
              AppSnackBar.showInfo(
                context,
                isArabic ? 'تم كتم المجموعة مؤقتًا' : 'Group muted successfully',
              );
            },
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: Colors.white,
            icon: Icons.volume_off_rounded,
            label: isArabic ? 'كتم' : 'Mute',
          ),
          SlidableAction(
            onPressed: (context) {
              AppSnackBar.showInfo(
                context,
                isArabic ? 'تم تثبيت الدردشة في الأعلى' : 'Group pinned to top',
              );
            },
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            icon: Icons.push_pin_rounded,
            label: isArabic ? 'تثبيت' : 'Pin',
          ),
        ],
      ),
      child: mainTile,
    );
  }
}

// ── Shared Add Options Bottom Sheet ──────────────────────────────────────────

class _AddOptionsSheet extends StatelessWidget {
  final String myId;
  final AuthProvider auth;
  final CommunityListBloc communityBloc;
  final GroupsListBloc groupsBloc;
  final BuildContext parentContext;

  const _AddOptionsSheet({
    required this.myId,
    required this.auth,
    required this.communityBloc,
    required this.groupsBloc,
    required this.parentContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              isArabic ? 'إنشاء أو انضمام' : 'Create or Join',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),

            // New Community
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_work_rounded, color: AppTheme.primary),
              ),
              title: Text(
                isArabic ? 'مجتمع جديد' : 'New Community',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isArabic ? 'قم بإنشاء مجتمع يحتوي على مجموعات متعددة' : 'Create a community with groups',
              ),
              onTap: () async {
                Navigator.pop(context);
                final newCommunity = await Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: communityBloc,
                      child: CreateCommunityScreen(
                        currentUserId: myId,
                        currentUserName: auth.currentUser?.name ?? 'User',
                        currentUserAvatarUrl: auth.currentUser?.avatarUrl,
                      ),
                    ),
                  ),
                );

                if (newCommunity != null && newCommunity is CommunityEntity) {
                  if (parentContext.mounted) {
                    Navigator.push(
                      parentContext,
                      MaterialPageRoute(
                        builder: (_) => CommunityDetailScreen(community: newCommunity),
                      ),
                    );
                    communityBloc.add(const CommunityListNewlyCreatedCleared());
                  }
                }
              },
            ),
            const SizedBox(height: 8),

            // New Standalone Group
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.secondary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded, color: AppTheme.secondary),
              ),
              title: Text(
                isArabic ? 'مجموعة جديدة' : 'New Group',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isArabic ? 'إنشاء مجموعة دردشة مستقلة' : 'Create a standalone group chat',
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  parentContext,
                  MaterialPageRoute(
                    builder: (_) => CreateGroupScreen(
                      currentUserId: myId,
                      currentUserName: auth.currentUser?.name ?? 'User',
                      currentUserAvatarUrl: auth.currentUser?.avatarUrl,
                      onGroupCreated: (name, desc, memberIds, imageUrl, isPublic) {
                        groupsBloc.add(GroupsListCreateGroup(
                          name: name,
                          description: desc,
                          ownerId: myId,
                          ownerName: auth.currentUser?.name ?? 'User',
                          ownerAvatarUrl: auth.currentUser?.avatarUrl,
                          initialMemberIds: memberIds,
                          imageUrl: imageUrl,
                          isPublic: isPublic,
                        ));
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Join via Invite Link
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_rounded, color: AppTheme.success),
              ),
              title: Text(
                isArabic ? 'الانضمام عبر رابط' : 'Join via Link',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isArabic ? 'الصق رابط دعوة لمجتمع أو لمجموعة' : 'Paste a community or group invite link',
              ),
              onTap: () {
                Navigator.pop(context);
                _showJoinLinkDialog(parentContext, isArabic);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinLinkDialog(BuildContext parentContext, bool isArabic) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: parentContext,
      useRootNavigator: true,
      builder: (dialogCtx) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isArabic ? 'الانضمام عبر رابط الدعوة' : 'Join via Invite Link'),
              content: isLoading
                  ? const SizedBox(
                      height: 100,
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : TextField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        hintText: isArabic ? 'أدخل رابط الدعوة هنا' : 'Paste invite link or token',
                      ),
                      textInputAction: TextInputAction.go,
                    ),
              actions: isLoading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final raw = ctrl.text.trim();
                          if (raw.isEmpty) return;

                          final link = _normalizeInviteLinkInput(raw);
                          
                          setState(() {
                            isLoading = true;
                          });

                          final communityRepo = CommunityRepositoryImpl();
                          final groupRepo = GroupRepositoryImpl();
                          final userName = auth.currentUser?.name ?? 'User';
                          final userAvatar = auth.currentUser?.avatarUrl;

                          try {
                            // 1. Check if token is for a Community
                            final community = await communityRepo.getCommunityByInviteLink(link);
                            if (community != null) {
                              final member = await communityRepo.getMember(
                                communityId: community.id,
                                userId: myId,
                              );

                              if (!dialogCtx.mounted) return;
                              Navigator.of(dialogCtx).pop(); // Close dialog

                              if (member != null) {
                                if (parentContext.mounted) {
                                  Navigator.of(parentContext).push(
                                    MaterialPageRoute(
                                      builder: (_) => CommunityDetailScreen(community: community),
                                    ),
                                  );
                                  AppSnackBar.showInfo(
                                    parentContext,
                                    isArabic ? 'لقد انضممت بالفعل إلى هذا المجتمع' : 'You have already joined this community.',
                                  );
                                }
                                return;
                              }

                              if (!community.isPublic) {
                                if (parentContext.mounted) {
                                  Navigator.of(parentContext).push(
                                    MaterialPageRoute(
                                      builder: (_) => CommunityJoinRequestScreen(
                                        community: community,
                                        token: link,
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              await communityRepo.joinCommunity(
                                communityId: community.id,
                                userId: myId,
                                userName: userName,
                                userAvatarUrl: userAvatar,
                              );

                              if (parentContext.mounted) {
                                Navigator.of(parentContext).push(
                                  MaterialPageRoute(
                                    builder: (_) => CommunityDetailScreen(community: community),
                                  ),
                                );
                                AppSnackBar.showSuccess(
                                  parentContext,
                                  isArabic ? 'تم الانضمام إلى المجتمع بنجاح!' : 'Joined community successfully!',
                                );
                              }
                              return;
                            }

                            // 2. Check if token is for a Group
                            final group = await groupRepo.getGroupByInviteLink(link);
                            if (group != null) {
                              if (group.isMember(myId)) {
                                if (!dialogCtx.mounted) return;
                                Navigator.of(dialogCtx).pop(); // Close dialog

                                if (parentContext.mounted) {
                                  Navigator.of(parentContext).push(
                                    MaterialPageRoute(
                                      builder: (_) => GroupChatScreen(
                                        groupId: group.id,
                                        currentUserId: myId,
                                        currentUserName: userName,
                                        currentUserAvatarUrl: userAvatar,
                                      ),
                                    ),
                                  );
                                  AppSnackBar.showInfo(
                                    parentContext,
                                    isArabic ? 'لقد انضممت بالفعل إلى هذه المجموعة' : 'You have already joined this group.',
                                  );
                                }
                                return;
                              }

                              final inviteRepo = GroupInviteRepositoryImpl();
                              final invite = await inviteRepo.getInvite(link);

                              if (!dialogCtx.mounted) return;
                              Navigator.of(dialogCtx).pop(); // Close dialog

                              final requiresApproval = (invite != null && invite.requiresApproval) || !group.isPublic;

                              if (requiresApproval) {
                                if (parentContext.mounted) {
                                  Navigator.of(parentContext).push(
                                    MaterialPageRoute(
                                      builder: (_) => JoinRequestScreen(token: link),
                                    ),
                                  );
                                }
                                return;
                              }

                              await groupRepo.joinViaInviteLink(
                                groupId: group.id,
                                userId: myId,
                                userName: userName,
                                userAvatarUrl: userAvatar,
                              );

                              if (parentContext.mounted) {
                                Navigator.of(parentContext).push(
                                  MaterialPageRoute(
                                    builder: (_) => GroupChatScreen(
                                      groupId: group.id,
                                      currentUserId: myId,
                                      currentUserName: userName,
                                      currentUserAvatarUrl: userAvatar,
                                    ),
                                  ),
                                );
                                AppSnackBar.showSuccess(
                                  parentContext,
                                  isArabic ? 'تم الانضمام إلى المجموعة بنجاح!' : 'Joined group successfully!',
                                );
                              }
                              return;
                            }

                            if (dialogCtx.mounted) {
                              setState(() {
                                isLoading = false;
                              });
                              AppSnackBar.showError(
                                dialogCtx,
                                isArabic ? 'رابط دعوة غير صالح أو منتهي الصلاحية' : 'Invalid or expired invite link.',
                              );
                            }
                          } catch (e) {
                            debugPrint('[JoinInviteLink] $e');
                            if (dialogCtx.mounted) {
                              setState(() {
                                isLoading = false;
                              });
                              AppSnackBar.showError(
                                dialogCtx,
                                isArabic ? 'حدث خطأ ما. يرجى المحاولة لاحقًا' : 'Something went wrong. Please try again.',
                              );
                            }
                          }
                        },
                        child: Text(isArabic ? 'انضمام' : 'Join'),
                      ),
                    ],
            );
          },
        );
      },
    ).whenComplete(ctrl.dispose);
  }
}

String _normalizeInviteLinkInput(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return s;
  if (s.contains('://')) {
    try {
      final uri = Uri.parse(s);
      final token = uri.queryParameters['token'];
      if (token != null && token.trim().isNotEmpty) {
        return token.trim();
      }
      if (uri.pathSegments.contains('invite')) {
        final idx = uri.pathSegments.indexOf('invite');
        if (idx + 1 < uri.pathSegments.length) {
          final seg = uri.pathSegments[idx + 1].trim();
          if (seg.isNotEmpty) return Uri.decodeComponent(seg);
        }
      }
      if (uri.pathSegments.isNotEmpty) {
        final seg = uri.pathSegments.last;
        if (seg.length >= 8) return Uri.decodeComponent(seg);
      }
    } catch (_) {}
  }
  if (s.contains('/')) {
    final last = s.split('/').last.split('?').first.trim();
    if (last.length >= 8) return last;
  }
  return s;
}

// ── Empty & Error States ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.15),
                    AppTheme.secondary.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Icon(icon, size: 56, color: AppTheme.primary.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13.5,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 52, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
