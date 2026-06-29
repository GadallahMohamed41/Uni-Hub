import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/features/home/presentation/widgets/university_feed_header.dart';
import 'package:project_test2/features/home/presentation/widgets/post_card.dart';
import 'package:project_test2/features/home/presentation/widgets/comments_sheet.dart';
import 'package:project_test2/features/home/presentation/widgets/create_post_sheet.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/utils/reactions.dart';
import 'package:project_test2/core/widgets/reaction_picker.dart';
import 'package:project_test2/features/profile/presentation/screens/notifications_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/profile_screen.dart';
import 'package:project_test2/core/layout/main_layout.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/home/data/models/comment_model.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  bool _searchMode = false;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  bool get wantKeepAlive => true;

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
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              style:
                  TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: TextStyle(
                    color: isDark ? Colors.white60 : AppTheme.textSecondary),
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
                size: 20),
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

  void _navigateToProfile(String userId) {
    if (userId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(userId: userId),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = context.read<AuthProvider>().userId;
      context.read<PostsProvider>().listenToPosts(currentUserId: currentUserId);
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMorePosts();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _showCreatePostSheet(
      {List<Uint8List>? initialImages, Uint8List? initialVideo}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return CreatePostSheet(
          initialImages: initialImages,
          initialVideo: initialVideo,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        key: const PageStorageKey('home_feed_scroll'),
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
                onTapComposer: _showCreatePostSheet,
                onTapPhoto: _showCreatePostSheet,
                onTapVideo: () async {
                  final XFile? video =
                      await _picker.pickVideo(source: ImageSource.gallery);
                  if (video == null) return;
                  final bytes = await video.readAsBytes();
                  if (!mounted) return;
                  _showCreatePostSheet(initialVideo: bytes);
                },
                onTapEvent: () {
                  _showCreatePostSheet();
                },
                onTapNotifications: () {
                  if (userId != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    );
                  }
                },
                onTapSearch: () => setState(() => _searchMode = true),
              ),
            ),
          Consumer<PostsProvider>(
            builder: (context, provider, __) {
              final filteredPosts = _searchQuery.isEmpty
                  ? provider.posts
                  : provider.posts.where((p) {
                      final q = _searchQuery.toLowerCase();
                      return p.text.toLowerCase().contains(q) ||
                          p.userName.toLowerCase().contains(q) ||
                          p.userBio.toLowerCase().contains(q);
                    }).toList();

              if (filteredPosts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.post_add_rounded,
                          size: 64,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No posts yet",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Be the first to share something!",
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PostCard(
                        post: filteredPosts[index],
                        onShowComment: (p) => showCommentsSheet(context, p),
                        onShowRepost: (p) => _showRepostSheet(p),
                        onShowReactionPicker: (p, pos) =>
                            _showReactionPicker(p, pos),
                        onUserTap: _navigateToProfile,
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
              );
            },
          ),
          Consumer<PostsProvider>(
            builder: (context, provider, _) {
              if (provider.isLoadingMorePosts) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              return const SliverToBoxAdapter(child: SizedBox(height: 100));
            },
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(PostModel post, Offset globalPosition) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;
    showReactionPickerPopover(
      context: context,
      globalPosition: globalPosition,
      onSelect: (type) {
        final postsProvider = context.read<PostsProvider>();
        if (type == ReactionType.like) {
          postsProvider.toggleLike(post.id, userId);
        }
        if (type == ReactionType.laugh) {
          postsProvider.toggleLaugh(post.id, userId);
        }
        if (type == ReactionType.support) {
          postsProvider.toggleSupport(post.id, userId);
        }
      },
    );
  }

  void _showRepostSheet(PostModel post) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;
    String caption = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final isCreatingPost = context.select<PostsProvider, bool>((p) => p.isCreatingPost);
            return Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Repost",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (v) => caption = v,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Add a caption...",
                      hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        if (post.imageUrls.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                                imageUrl: post.imageUrls.first,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover),
                          )
                        else
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: post.userAvatarUrl != null
                                ? CachedNetworkImageProvider(
                                    post.userAvatarUrl!,
                                    maxWidth: 100,
                                    maxHeight: 100)
                                : null,
                            child: post.userAvatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.userName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface),
                              ),
                              Text(
                                post.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isCreatingPost
                          ? null
                          : () async {
                              if (user.isBlocked) {
                                if (user.blockedUntil != null &&
                                    user.blockedUntil!
                                        .isAfter(DateTime.now())) {
                                  AppSnackBar.showError(context,
                                      'You are blocked from reposting until ${user.blockedUntil.toString().split('.')[0]}');
                                  return;
                                } else if (user.blockedUntil == null) {
                                  AppSnackBar.showError(context,
                                      'You are permanently blocked from reposting');
                                  return;
                                }
                              }

                              final ok = await context
                                  .read<PostsProvider>()
                                  .createRepost(
                                    userId: user.uid,
                                    userName: user.name,
                                    userBio: user.bio ?? 'Student',
                                    userAvatarUrl: user.avatarUrl,
                                    originalPostId: post.id,
                                    text: caption,
                                  );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (ok) {
                                AppSnackBar.showSuccess(
                                    context, "Reposted successfully");
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isCreatingPost
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Repost Now"),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class CommentThreadItem extends StatefulWidget {
  final CommentModel comment;
  final PostModel post;
  final PostsProvider postsProvider;
  final AuthProvider authProvider;
  final VoidCallback onReplyTap;

  const CommentThreadItem({
    super.key,
    required this.comment,
    required this.post,
    required this.postsProvider,
    required this.authProvider,
    required this.onReplyTap,
  });

  @override
  State<CommentThreadItem> createState() => _CommentThreadItemState();
}

class _CommentThreadItemState extends State<CommentThreadItem> {
  late Stream<List<CommentModel>> _repliesStream;

  @override
  void initState() {
    super.initState();
    _repliesStream = widget.postsProvider.getCommentRepliesStream(widget.comment.id);
  }

  @override
  void didUpdateWidget(covariant CommentThreadItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment.id != widget.comment.id) {
      _repliesStream = widget.postsProvider.getCommentRepliesStream(widget.comment.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return StreamBuilder<List<CommentModel>>(
      stream: _repliesStream,
      builder: (context, repliesSnapshot) {
        final replies = repliesSnapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: widget.comment.userAvatarUrl != null
                        ? CachedNetworkImageProvider(
                            widget.comment.userAvatarUrl!,
                            maxWidth: 100,
                            maxHeight: 100)
                        : null,
                    child: widget.comment.userAvatarUrl == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.comment.userName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                widget.comment.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.comment.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: widget.onReplyTap,
                                child: const Text('Reply',
                                    style: TextStyle(fontSize: 12)),
                              ),
                              if (widget.comment.repliesCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '${widget.comment.repliesCount} replies',
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                        fontSize: 12),
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
              if (replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 50, top: 8),
                  child: Column(
                    children: replies.map((reply) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: reply.userAvatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      reply.userAvatarUrl!,
                                      maxWidth: 100,
                                      maxHeight: 100)
                                  : null,
                              child: reply.userAvatarUrl == null
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : AppTheme.surfaceVariant
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reply.userName,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reply.text,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
