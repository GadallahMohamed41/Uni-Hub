
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/features/home/presentation/widgets/comments_sheet.dart';
import 'package:project_test2/features/home/presentation/widgets/post_enhancements/enhanced_create_post_sheet.dart';
import 'package:project_test2/features/home/presentation/widgets/post_enhancements/enhanced_post_card.dart';
import 'package:project_test2/features/home/presentation/widgets/university_feed_header.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
import 'package:project_test2/features/home/data/services/post_enhancements_service.dart';
import 'package:project_test2/features/profile/presentation/screens/profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/notifications_screen.dart';
import 'package:project_test2/core/layout/main_layout.dart';
 
class EnhancedHomeScreen extends StatefulWidget {
  const EnhancedHomeScreen({super.key});

  @override
  State<EnhancedHomeScreen> createState() => _EnhancedHomeScreenState();
}

class _EnhancedHomeScreenState extends State<EnhancedHomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  bool _searchMode = false;
  final ScrollController _scrollCtrl = ScrollController();
  final PostEnhancementsService _enhService = PostEnhancementsService();

  Set<String>? _connectionIds;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().listenToPosts();
      _loadConnections();
    });
  }

  Future<void> _loadConnections() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId.isEmpty) return;
    try {
      final ids = await _enhService.getConnectionIds(userId);
      if (mounted) {
        setState(() {
          _connectionIds = ids;
        });
      }
    } catch (_) {}
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMorePosts();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showEnhancedCreatePostSheet({List<Uint8List>? initialImages, Uint8List? initialVideo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EnhancedCreatePostSheet(
          initialImages: initialImages,
          initialVideo: initialVideo,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<PostsProvider>(
        builder: (context, provider, _) {
          // 1. Filter locally/client-side based on search query
          final searchedPosts = _searchQuery.isEmpty
              ? provider.posts
              : provider.posts.where((p) {
                  final q = _searchQuery.toLowerCase();
                  return p.text.toLowerCase().contains(q) ||
                      p.userName.toLowerCase().contains(q) ||
                      p.userBio.toLowerCase().contains(q);
                }).toList();

          // 2. Perform Privacy Filtering (Public, Friends Only, Private) synchronously
          final filteredPosts = _connectionIds == null
              ? searchedPosts.where((p) => p.privacyLevel == 'everyone' || p.userId == userId).toList()
              : searchedPosts.where((post) {
                  if (post.userId == userId) return true;
                  final privacy = post.privacyLevel;
                  switch (privacy) {
                    case 'everyone':
                    case 'public':
                      return true;
                    case 'friends':
                    case 'friends_only':
                      return _connectionIds!.contains(post.userId);
                    case 'only_me':
                    case 'private':
                      return false;
                    default:
                      return true;
                  }
                }).toList();

          return CustomScrollView(
            key: const PageStorageKey('enhanced_home_feed_scroll'),
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              if (_searchMode)
                SliverAppBar(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  automaticallyImplyLeading: false,
                  title: _buildSearchBar(),
                )
              else
                SliverToBoxAdapter(
                  child: UniversityFeedHeader(
                    userId: userId,
                    onTapAvatar: () {
                      final authProvider = context.read<AuthProvider>();
                      if (authProvider.currentUser != null) {
                        if (MainLayoutState.instance != null) {
                          MainLayoutState.instance!.goToProfile();
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        }
                      }
                    },
                    onTapComposer: _showEnhancedCreatePostSheet,
                    onTapPhoto: _showEnhancedCreatePostSheet,
                    onTapVideo: () async {
                      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                      if (video == null) return;
                      final bytes = await video.readAsBytes();
                      if (!mounted) return;
                      _showEnhancedCreatePostSheet(initialVideo: bytes);
                    },
                    onTapEvent: () => _showEnhancedCreatePostSheet(),
                    onTapNotifications: () {
                      if (userId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      }
                    },
                    onTapSearch: () => setState(() => _searchMode = true),
                  ),
                ),
              
              if (filteredPosts.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.post_add_rounded, size: 64, color: AppTheme.textTertiary),
                        SizedBox(height: 16),
                        Text("No posts available", style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        EnhancedPostCard(
                          post: filteredPosts[index],
                          onShowComment: (p) => showCommentsSheet(context, p),
                          onShowRepost: (p) {},
                          onShowReactionPicker: (p, pos) {},
                          onUserTap: (uid) {},
                        ),
                        Container(
                          height: 6,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                    childCount: filteredPosts.length,
                    addSemanticIndexes: false,
                  ),
                ),
              
              if (provider.isLoadingMorePosts)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                  ),
                )
              else
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.primary.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: isDark ? Colors.white70 : AppTheme.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
              decoration: const InputDecoration(hintText: "Search", border: InputBorder.none),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : AppTheme.textSecondary, size: 20),
            onPressed: () => setState(() {
              _searchMode = false;
              _searchQuery = '';
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
