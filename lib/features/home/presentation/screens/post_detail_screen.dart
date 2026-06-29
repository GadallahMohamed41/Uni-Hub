import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/reactions.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/home/data/models/comment_model.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/profile_screen.dart';
import 'package:project_test2/core/widgets/custom_confirm_dialog.dart';
import 'package:project_test2/core/widgets/reaction_picker.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final String? initialCommentId;
  final String? parentCommentId;
  final bool focusCommentInput;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialCommentId,
    this.parentCommentId,
    this.focusCommentInput = false,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _commentsHeaderKey = GlobalKey();
  final Map<String, GlobalKey> _commentKeys = <String, GlobalKey>{};
  final Map<String, int> _visibleRepliesCount = <String, int>{};
  bool _didScrollToInitial = false;
  PostModel? _post;

  /// Shown when the post is not in [PostsProvider] (e.g. pending review) and
  /// Firestore fetch fails or times out.
  String? _loadError;
  bool _isLoadingRemote = false;

  PostsProvider? _postsProvider;
  bool _postsListenerAttached = false;

  // Inline reply state
  String? _replyToCommentId;
  String? _replyToUserName;

  // @Mention state
  bool _showMentionOverlay = false;
  String _mentionQuery = '';
  List<UserModel> _mentionResults = [];
  Timer? _mentionDebounce;
  final List<String> _mentionedUserIds = [];

  // Comment highlight state
  String? _highlightedCommentId;
  bool _highlightCommentsHeader = false;

  bool _isSendingComment = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onCommentTextChanged);
    if (widget.postId.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _loadError = 'Invalid post link.');
      });
      return;
    }
    _loadPost();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_post == null && _loadError == null) {
        _fetchPostFromServer();
      }
    });
  }

  void _loadPost() {
    final id = widget.postId.trim();
    if (id.isEmpty) return;
    final postsProvider = context.read<PostsProvider>();
    final posts = postsProvider.posts;
    if (posts.isEmpty) return;
    try {
      final post = posts.firstWhere((p) => p.id == id);
      if (mounted) {
        setState(() => _post = post);
      }
    } catch (_) {
      // Not in the in-memory feed (common for pending posts or notification deep links).
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_postsListenerAttached) return;
    _postsProvider = context.read<PostsProvider>();
    _postsProvider!.addListener(_onPostsProviderUpdated);
    _postsListenerAttached = true;
    _onPostsProviderUpdated();
  }

  void _onPostsProviderUpdated() {
    if (!mounted || _post != null) return;
    final id = widget.postId.trim();
    if (id.isEmpty) return;
    final posts = _postsProvider?.posts ?? [];
    for (final p in posts) {
      if (p.id == id) {
        setState(() {
          _post = p;
          _isLoadingRemote = false;
          _loadError = null;
        });
        break;
      }
    }
  }

  Future<void> _fetchPostFromServer() async {
    final id = widget.postId.trim();
    if (id.isEmpty) return;
    if (!mounted) return;
    if (_post != null) return;

    setState(() {
      _isLoadingRemote = true;
      _loadError = null;
    });

    try {
      final fetched =
          await FirestoreService().getPostById(id).timeout(const Duration(seconds: 25));
      if (!mounted) return;
      if (_post != null) {
        setState(() => _isLoadingRemote = false);
        return;
      }
      if (fetched != null) {
        setState(() {
          _post = fetched;
          _isLoadingRemote = false;
        });
        debugPrint('[PostDetailScreen] Loaded post $id from Firestore (status=${fetched.status}).');
      } else {
        setState(() {
          _isLoadingRemote = false;
          _loadError =
              'This post could not be found. It may have been removed or is no longer available.';
        });
        debugPrint('[PostDetailScreen] Post document missing for id=$id');
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoadingRemote = false;
        _loadError =
            'This is taking too long. Check your connection and tap Retry, or open the post again later.';
      });
      debugPrint('[PostDetailScreen] Firestore timeout for post id=$id');
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isLoadingRemote = false;
        _loadError = 'Could not load this post. Please try again.';
      });
      debugPrint('[PostDetailScreen] Firestore error for id=$id: $e\n$st');
    }
  }

  @override
  void dispose() {
    if (_postsListenerAttached) {
      _postsProvider?.removeListener(_onPostsProviderUpdated);
    }
    _commentController.removeListener(_onCommentTextChanged);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    _mentionDebounce?.cancel();
    super.dispose();
  }

  GlobalKey _commentKey(String id) {
    return _commentKeys.putIfAbsent(id, () => GlobalKey());
  }

  void _maybeScrollToInitialComment(List<CommentModel> comments) {
    if (_didScrollToInitial) return;

    final targetHighlight = (widget.initialCommentId ?? '').trim();
    final targetScroll = (widget.parentCommentId ?? widget.initialCommentId ?? '').trim();
    
    if (targetScroll.isEmpty) {
      if (widget.focusCommentInput) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _commentFocusNode.requestFocus();
        });
      }
      _didScrollToInitial = true;
      return;
    }

    final hasTarget = comments.any((c) => c.id == targetScroll);
    final key = hasTarget ? _commentKeys[targetScroll] : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key?.currentContext ?? _commentsHeaderKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
        alignment: 0.15,
      );
      // تفعيل تأثير الإبراز المرئي
      if (targetHighlight.isNotEmpty) {
        setState(() => _highlightedCommentId = targetHighlight);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _highlightedCommentId = null);
        });
      }
      if (widget.focusCommentInput) {
        _commentFocusNode.requestFocus();
      }
    });
    _didScrollToInitial = true;
  }

  // ============ @Mention Detection ============
  void _onCommentTextChanged() {
    final text = _commentController.text;
    final cursorPos = _commentController.selection.baseOffset;
    if (cursorPos < 0 || cursorPos > text.length) {
      if (_showMentionOverlay) setState(() => _showMentionOverlay = false);
      return;
    }

    // Find the '@' before cursor
    final beforeCursor = text.substring(0, cursorPos);
    final lastAt = beforeCursor.lastIndexOf('@');
    if (lastAt == -1) {
      if (_showMentionOverlay) setState(() => _showMentionOverlay = false);
      return;
    }

    final query = beforeCursor.substring(lastAt + 1);
    // If there's a space in the query, hide
    if (query.contains(' ')) {
      if (_showMentionOverlay) setState(() => _showMentionOverlay = false);
      return;
    }

    _mentionQuery = query;
    if (!_showMentionOverlay) setState(() => _showMentionOverlay = true);

    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final userId = context.read<AuthProvider>().userId;
        if (userId == null) return;
        final results = await FirestoreService().searchConnections(userId, _mentionQuery);
        if (mounted) setState(() => _mentionResults = results);
      } catch (_) {}
    });
  }

  void _selectMention(UserModel user) {
    final text = _commentController.text;
    final cursorPos = _commentController.selection.baseOffset;
    final beforeCursor = text.substring(0, cursorPos);
    final lastAt = beforeCursor.lastIndexOf('@');
    if (lastAt == -1) return;

    final afterCursor = text.substring(cursorPos);
    final replacement = '@${user.name} ';
    final newText = text.substring(0, lastAt) + replacement + afterCursor;
    _commentController.text = newText;
    _commentController.selection = TextSelection.collapsed(
      offset: lastAt + replacement.length,
    );

    if (!_mentionedUserIds.contains(user.uid)) {
      _mentionedUserIds.add(user.uid);
    }
    setState(() {
      _showMentionOverlay = false;
      _mentionResults = [];
    });
  }

  // ============ Inline Reply ============
  void _startReply(CommentModel comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _replyToUserName = comment.userName;
    });
    _commentController.clear();
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToCommentId = null;
      _replyToUserName = null;
    });
    _commentController.clear();
    _mentionedUserIds.clear();
  }

  Future<void> _sharePost(PostModel post) async {
    try {
      String shareText = '${post.userName}: ${post.text}';
      if (post.imageUrls.isNotEmpty) {
        shareText += '\n\n${post.imageUrls.first}';
      } else if (post.imageUrl != null) {
        shareText += '\n\n${post.imageUrl}';
      }
      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to share post');
      }
    }
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
        if (type == ReactionType.like) postsProvider.toggleLike(post.id, userId);
        if (type == ReactionType.laugh) postsProvider.toggleLaugh(post.id, userId);
        if (type == ReactionType.support) postsProvider.toggleSupport(post.id, userId);
      },
    );
  }

  void _navigateToProfile(String targetUserId) {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userId == targetUserId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: targetUserId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);
    final postsProvider = context.watch<PostsProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final id = widget.postId.trim();

    PostModel? post = _post;
    if (post == null && id.isNotEmpty) {
      final posts = postsProvider.posts;
      try {
        post = posts.firstWhere((p) => p.id == id);
      } catch (_) {
        // Still resolving via Firestore or error.
      }
    }

    if (post == null) {
      if (_loadError != null) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(title: const Text('Post')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 56,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _loadError = null);
                      _fetchPostFromServer();
                    },
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Post')),
        body: Column(
          children: [
            if (_isLoadingRemote)
              const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: _PostDetailLoadingSkeleton(isDark: isDark),
            ),
          ],
        ),
      );
    }

    final postModel = post;
    final postId = postModel.id;

    final isLiked = userId != null && postModel.isLikedByUser(userId);
    final isLaughed = userId != null && postModel.isLaughedByUser(userId);
    final isSupported = userId != null && postModel.isSupportedByUser(userId);

    final currentReaction = isLaughed
        ? ReactionType.laugh
        : (isSupported ? ReactionType.support : (isLiked ? ReactionType.like : null));
    final reactIcon = ReactionUi.iconFor(currentReaction);
    final reactLabel = ReactionUi.labelFor(currentReaction);
    final reactColor = ReactionUi.colorFor(currentReaction);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () => _sharePost(postModel),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () => _navigateToProfile(postModel.userId),
                                child: CircleAvatar(
                                  radius: 26,
                                  backgroundImage: postModel.userAvatarUrl != null
                                      ? CachedNetworkImageProvider(postModel.userAvatarUrl!)
                                      : null,
                                  child: postModel.userAvatarUrl == null
                                      ? const Icon(Icons.person, size: 26)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _navigateToProfile(postModel.userId),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        postModel.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        postModel.userBio,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        postModel.formattedTime,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Text
                        if (postModel.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              postModel.text,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        _buildMedia(postModel),
                        // Reactions Count
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              if (postModel.totalReactions > 0)
                                Row(
                                  children: [
                                    if (postModel.likesCount > 0)
                                      Row(
                                        children: [
                                          const Icon(Icons.thumb_up, size: 16, color: AppTheme.info),
                                          const SizedBox(width: 4),
                                          Text(
                                            "${postModel.likesCount}",
                                            style: TextStyle(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    if (postModel.laughedCount > 0) ...[
                                      const SizedBox(width: 8),
                                      const Text("😊", style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${postModel.laughedCount}",
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (postModel.supportedCount > 0) ...[
                                      const SizedBox(width: 8),
                                      const Text("❤️", style: TextStyle(fontSize: 14)),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${postModel.supportedCount}",
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () {
                                  final ctx = _commentsHeaderKey.currentContext;
                                  if (ctx == null) return;
                                  Scrollable.ensureVisible(
                                    ctx,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOut,
                                    alignment: 0.15,
                                  );
                                  setState(() => _highlightCommentsHeader = true);
                                  Future.delayed(const Duration(milliseconds: 500), () {
                                    if (!mounted) return;
                                    setState(() => _highlightCommentsHeader = false);
                                  });
                                },
                                child: Text(
                                  "${postModel.commentsCount} comments",
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          height: 1, 
                          color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.surfaceVariant
                        ),

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  theme.cardTheme.color ?? theme.colorScheme.surface,
                                  (theme.cardTheme.color ?? theme.colorScheme.surface).withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              children: [
                                _buildActionButton(
                                  reactIcon,
                                  reactLabel,
                                  reactColor,
                                  isLiked || isLaughed || isSupported,
                                  () {
                                    if (userId == null) return;
                                    if (isLaughed) {
                                      postsProvider.toggleLaugh(postId, userId);
                                      return;
                                    }
                                    if (isSupported) {
                                      postsProvider.toggleSupport(postId, userId);
                                      return;
                                    }
                                    postsProvider.toggleLike(postId, userId);
                                  },
                                  onLongPressStart: (pos) => _showReactionPicker(postModel, pos),
                                ),
                                _buildActionButton(
                                  Icons.comment_outlined,
                                  "Comment",
                                  AppTheme.info,
                                  false,
                                  () => _commentFocusNode.requestFocus(),
                                ),
                                _buildActionButton(
                                  Icons.repeat_rounded,
                                  "Repost",
                                  AppTheme.warning,
                                  false,
                                  () => _showRepostSheet(postModel),
                                ),
                                _buildActionButton(
                                  Icons.share_outlined,
                                  "Share",
                                  theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  false,
                                  () => _sharePost(postModel),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Comments Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _highlightCommentsHeader
                            ? (isDark
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.primary.withValues(alpha: 0.08))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Comments',
                        key: _commentsHeaderKey,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<CommentModel>>(
                    stream: postsProvider.getPostCommentsThreadStream(postId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Failed to load comments. Please try again.',
                              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final comments = snapshot.data ?? [];
                      _maybeScrollToInitialComment(comments);

                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No comments yet",
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final idToComment = <String, CommentModel>{
                        for (final c in comments) c.id: c,
                      };
                      final childrenByParent = <String?, List<CommentModel>>{};
                      for (final c in comments) {
                        final parentId = c.parentCommentId;
                        childrenByParent.putIfAbsent(parentId, () => <CommentModel>[]).add(c);
                      }
                      final rootComments = <CommentModel>[];
                      for (final c in comments) {
                        final parentId = c.parentCommentId;
                        if (parentId == null || !idToComment.containsKey(parentId)) {
                          rootComments.add(c);
                        }
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: rootComments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final comment = rootComments[index];
                          return KeyedSubtree(
                            key: _commentKey(comment.id),
                            child: _buildCommentItem(
                              comment,
                              postModel,
                              postsProvider,
                              authProvider,
                              childrenByParent,
                              0,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // @Mention overlay + Reply tag + Comment Input
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // @Mention search overlay
              if (_showMentionOverlay && _mentionResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.surfaceVariant,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _mentionResults.length,
                    itemBuilder: (context, index) {
                      final user = _mentionResults[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage: user.avatarUrl != null
                              ? CachedNetworkImageProvider(user.avatarUrl!)
                              : null,
                          child: user.avatarUrl == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        title: Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        subtitle: Text(
                          user.bio ?? user.department ?? 'Student',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _selectMention(user),
                      );
                    },
                  ),
                ),

              // Reply tag banner
              if (_replyToCommentId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withValues(alpha: 0.08)
                        : AppTheme.primary.withValues(alpha: 0.05),
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.reply_rounded, size: 16, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Replying to @${_replyToUserName ?? ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _cancelReply,
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),

              // Comment Input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color ?? theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        focusNode: _commentFocusNode,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          hintText: _replyToCommentId != null
                              ? "Write a reply..."
                              : "Write a comment...",
                          hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                          filled: true,
                          fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () async {
                          if (_isSendingComment) return;
                          final user = authProvider.currentUser;
                          if (user != null && user.isBlocked) {
                            if (user.blockedUntil != null && user.blockedUntil!.isAfter(DateTime.now())) {
                              AppSnackBar.showError(context, 'You are blocked from commenting until ${user.blockedUntil.toString().split('.')[0]}');
                              return;
                            } else if (user.blockedUntil == null) {
                              AppSnackBar.showError(context, 'You are permanently blocked from commenting');
                              return;
                            }
                          }
                          
                          if (_commentController.text.trim().isNotEmpty) {
                            if (user != null) {
                              setState(() {
                                _isSendingComment = true;
                              });
                              final newId = await postsProvider.addComment(
                                postId: postId,
                                userId: user.uid,
                                userName: user.name,
                                userAvatarUrl: user.avatarUrl,
                                text: _commentController.text,
                                parentCommentId: _replyToCommentId,
                                mentionedUserIds: _mentionedUserIds.isNotEmpty
                                    ? List<String>.from(_mentionedUserIds)
                                    : null,
                              );
                              _commentController.clear();
                              _mentionedUserIds.clear();
                              if (newId != null) {
                                final highlightId = newId;
                                setState(() {
                                  _replyToCommentId = null;
                                  _replyToUserName = null;
                                  _highlightedCommentId = highlightId;
                                  _isSendingComment = false;
                                });
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (!mounted) return;
                                  final key = _commentKeys[highlightId];
                                  final ctx = key?.currentContext;
                                  if (ctx == null) return;
                                  Scrollable.ensureVisible(
                                    ctx,
                                    duration: const Duration(milliseconds: 320),
                                    curve: Curves.easeOut,
                                    alignment: 0.2,
                                  );
                                });
                                Future.delayed(const Duration(seconds: 3), () {
                                  if (!mounted) return;
                                  if (_highlightedCommentId == highlightId) {
                                    setState(() {
                                      _highlightedCommentId = null;
                                    });
                                  }
                                });
                              } else {
                                setState(() {
                                  _replyToCommentId = null;
                                  _replyToUserName = null;
                                  _isSendingComment = false;
                                });
                              }
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    bool isActive,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
    void Function(Offset globalPosition)? onLongPressStart,
  }) {
    return Expanded(
      child: AnimatedBuilder(
        animation: AlwaysStoppedAnimation(0),
        builder: (context, child) {
          final ink = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(16),
              splashColor: color.withValues(alpha: 0.1),
              highlightColor: color.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );

          if (onLongPressStart == null) return ink;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPressStart: (d) => onLongPressStart(d.globalPosition),
            child: ink,
          );
        },
      ),
    );
  }

  Widget _buildMedia(PostModel post) {
    if (post.imageUrls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: _AdaptiveMediaCarousel(
        urls: post.imageUrls,
        minHeight: 220,
        maxHeight: 420,
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildCommentItem(
    CommentModel comment,
    PostModel post,
    PostsProvider postsProvider,
    AuthProvider authProvider,
    Map<String?, List<CommentModel>> childrenByParent,
    int depth,
  ) {
    final currentUserId = authProvider.userId;
    final isOwner = currentUserId == comment.userId;
    final isLiked = comment.likedBy.contains(currentUserId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final replies = childrenByParent[comment.id] ?? const <CommentModel>[];
    final defaultVisible = replies.length <= 2 ? replies.length : 2;
    final visibleCount = _visibleRepliesCount[comment.id] ?? defaultVisible;
    final visibleReplies = replies.take(visibleCount).toList();
    final remaining = replies.length - visibleCount;
    final leftPadding = depth == 0 ? 0.0 : 50.0 + (depth - 1) * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: _highlightedCommentId == comment.id
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.6), width: 2)
              : null,
          color: _highlightedCommentId == comment.id
              ? AppTheme.primary.withValues(alpha: isDark ? 0.08 : 0.04)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _navigateToProfile(comment.userId),
                  child: CircleAvatar(
                    radius: depth == 0 ? 18 : 16,
                    backgroundImage: comment.userAvatarUrl != null
                        ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                        : null,
                    child: comment.userAvatarUrl == null
                        ? Icon(Icons.person, size: depth == 0 ? 18 : 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onLongPress:
                        isOwner ? () => _showCommentOptions(context, comment, post.id, postsProvider) : null,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comment.userName,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isOwner)
                                GestureDetector(
                                  onTap: () => _showCommentOptions(context, comment, post.id, postsProvider),
                                  child: Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.text,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                comment.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                              if (comment.isEdited) ...[
                                const SizedBox(width: 6),
                                Text(
                                  'Edited',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () {
                                  if (currentUserId != null) {
                                    postsProvider.toggleCommentLike(comment.id, currentUserId);
                                  }
                                },
                                child: Text(
                                  'Like',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isLiked
                                        ? AppTheme.primary
                                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              if (comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _showCommentLikes(context, comment),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    color: Colors.transparent,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.thumb_up, size: 10, color: AppTheme.primary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${comment.likesCount}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () => _startReply(comment),
                                child: Row(
                                  children: [
                                    Text(
                                      'Reply',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.info,
                                      ),
                                    ),
                                    if (replies.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (visibleReplies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: [
                    for (final reply in visibleReplies)
                      KeyedSubtree(
                        key: _commentKey(reply.id),
                        child: _buildCommentItem(
                          reply,
                          post,
                          postsProvider,
                          authProvider,
                          childrenByParent,
                          depth + 1,
                        ),
                      ),
                    if (remaining > 0)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _visibleRepliesCount[comment.id] = replies.length;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.only(left: 50, top: 4),
                            child: Text(
                              'View $remaining more replies',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
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

  void _showCommentLikes(BuildContext context, CommentModel comment) async {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<UserModel>>(
          future: FirestoreService().getUsersByIds(comment.likedBy),
          builder: (context, snapshot) {
            final users = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  const SizedBox(height: 24),
                  Text(
                    "Liked by",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    )
                  else if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text("No likes to show"),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _navigateToProfile(user.uid);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentOptions(BuildContext context, CommentModel comment, String postId, PostsProvider postsProvider) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                _showEditCommentDialog(context, comment, postsProvider);
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              ),
              title: const Text("Edit Comment", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () async {
                Navigator.pop(context);
                await CustomConfirmDialog.show(
                  context,
                  title: 'Delete Comment',
                  content: 'Are you sure you want to delete this comment?',
                  confirmLabel: 'Delete',
                  confirmColor: AppTheme.error,
                  icon: Icons.delete_forever_rounded,
                  onConfirm: () {
                    postsProvider.deleteComment(comment.id, postId, comment.parentCommentId);
                  },
                );
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_outline_rounded, color: AppTheme.error),
              ),
              title: const Text("Delete Comment", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.error)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditCommentDialog(BuildContext context, CommentModel comment, PostsProvider postsProvider) {
    final controller = TextEditingController(text: comment.text);
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
        title: Text('Edit Comment', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: "Update your comment...",
            hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                postsProvider.updateComment(comment.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
            final postsProvider = context.watch<PostsProvider>();
            return Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Preview original post
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.03) : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        if (post.imageUrls.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: post.imageUrls.first, width: 50, height: 50, fit: BoxFit.cover),
                          )
                        else
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: post.userAvatarUrl != null ? CachedNetworkImageProvider(post.userAvatarUrl!) : null,
                            child: post.userAvatarUrl == null ? const Icon(Icons.person) : null,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.userName,
                                style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                              ),
                              Text(
                                post.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
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
                      onPressed: postsProvider.isCreatingPost
                          ? null
                          : () async {
                        final authProvider = context.read<AuthProvider>();
                        final currentUser = authProvider.currentUser;
                        if (currentUser != null && currentUser.isBlocked) {
                          if (currentUser.blockedUntil != null && currentUser.blockedUntil!.isAfter(DateTime.now())) {
                            AppSnackBar.showError(context, 'You are blocked from reposting until ${currentUser.blockedUntil.toString().split('.')[0]}');
                            return;
                          } else if (currentUser.blockedUntil == null) {
                            AppSnackBar.showError(context, 'You are permanently blocked from reposting');
                            return;
                          }
                        }

                        final ok = await context.read<PostsProvider>().createRepost(
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
                          AppSnackBar.showSuccess(context, "Reposted successfully");
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: postsProvider.isCreatingPost
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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

class _PostDetailLoadingSkeleton extends StatelessWidget {
  final bool isDark;

  const _PostDetailLoadingSkeleton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final soft = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.08 : 0.06);
    final strong = theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.1);

    Widget bar(double? width, double height, {double bottom = 0}) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: soft,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: strong, shape: BoxShape.circle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(160, 14, bottom: 8),
                    bar(double.infinity, 12, bottom: 6),
                    bar(90, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          bar(double.infinity, 14, bottom: 10),
          bar(double.infinity, 14, bottom: 10),
          bar(200, 14, bottom: 24),
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: strong,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Loading post…',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdaptiveMediaCarousel extends StatefulWidget {
  final List<String> urls;
  final double minHeight;
  final double maxHeight;
  final BorderRadius borderRadius;
  const _AdaptiveMediaCarousel({
    required this.urls,
    required this.minHeight,
    required this.maxHeight,
    required this.borderRadius,
  });

  @override
  State<_AdaptiveMediaCarousel> createState() => _AdaptiveMediaCarouselState();
}

class _AdaptiveMediaCarouselState extends State<_AdaptiveMediaCarousel> {
  int _index = 0;
  final Map<String, double> _ratios = {};
  final Map<String, ImageStream> _streams = {};
  final Map<String, ImageStreamListener> _listeners = {};

  @override
  void didUpdateWidget(covariant _AdaptiveMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.urls.join('|') != widget.urls.join('|')) {
      _index = 0;
    }
  }

  void _resolveRatio(String url) {
    if (_ratios.containsKey(url)) return;
    final stream = CachedNetworkImageProvider(url).resolve(ImageConfiguration.empty);
    _streams[url] = stream;
    final listener = ImageStreamListener((info, _) {
      if (mounted) {
        setState(() => _ratios[url] = info.image.width / info.image.height);
      }
    });
    _listeners[url] = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    for (final url in _streams.keys) {
      _streams[url]?.removeListener(_listeners[url]!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.urls[_index];
    _resolveRatio(url);
    final ratio = _ratios[url] ?? 1.0;
    final screenWidth = MediaQuery.of(context).size.width - 40;
    final targetHeight = (screenWidth / ratio).clamp(widget.minHeight, widget.maxHeight);

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: targetHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.white.withValues(alpha: 0.05) 
                : AppTheme.surfaceVariant,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: widget.urls.length,
                onPageChanged: (v) => setState(() => _index = v),
                itemBuilder: (context, i) => CachedNetworkImage(
                  imageUrl: widget.urls[i],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              if (widget.urls.length > 1)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final active = i == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: active ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
