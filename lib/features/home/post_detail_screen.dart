import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:project_test2/core/app_snackbar.dart';
import '../../core/theme.dart';
import '../../core/reactions.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../profile/user_profile_screen.dart';
import '../../widgets/reaction_picker.dart';
import 'widgets/media_widgets.dart';

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  PostModel? _post;

  @override
  void initState() {
    super.initState();
    _loadPost();
  }

  void _loadPost() {
    final postsProvider = context.read<PostsProvider>();
    final posts = postsProvider.posts;
    if (posts.isNotEmpty) {
      try {
        final post = posts.firstWhere((p) => p.id == widget.postId);
        if (mounted) {
          setState(() => _post = post);
        }
      } catch (e) {
        // Post not found in current list, will be loaded from stream
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sharePost(PostModel post) async {
    try {
      String shareText = '${post.userName}: ${post.text}';
      if (post.imageUrls.isNotEmpty) {
        shareText += '\n\n${post.imageUrls.first}';
      } else if (post.imageUrl != null) {
        shareText += '\n\n${post.imageUrl}';
      }
      await Share.share(shareText);
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to share post');
      }
    }
  }

  void _showReactionPicker(PostModel post) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;
    showReactionPickerDialog(
      context: context,
      onSelect: (type) {
        final postsProvider = context.read<PostsProvider>();
        if (type == ReactionType.like) postsProvider.toggleLike(post.id, userId);
        if (type == ReactionType.laugh) postsProvider.toggleLaugh(post.id, userId);
        if (type == ReactionType.support) postsProvider.toggleSupport(post.id, userId);
      },
    );
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final postsProvider = context.watch<PostsProvider>();
    final userId = authProvider.userId;

    PostModel? post = _post;
    if (post == null) {
      final posts = postsProvider.posts;
      try {
        post = posts.firstWhere((p) => p.id == widget.postId);
      } catch (e) {
        // Post not found
      }
    }

    if (post == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('Post'),
        ),
        body: const Center(child: CircularProgressIndicator()),
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
      backgroundColor: AppTheme.background,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Post Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                          color: AppTheme.textMain,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        postModel.userBio,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        postModel.formattedTime,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textTertiary,
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
                              style: const TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: AppTheme.textMain,
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
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
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
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
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
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              const Spacer(),
                              Text(
                                "${postModel.commentsCount} comments",
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1, color: AppTheme.surfaceVariant),

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.surface,
                                  AppTheme.surface.withOpacity(0.5),
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
                                  onLongPress: () => _showReactionPicker(postModel),
                                ),
                                _buildActionButton(
                                  Icons.comment_outlined,
                                  "Comment",
                                  AppTheme.info,
                                  false,
                                  () => _commentFocusNode.requestFocus(),
                                ),
                                _buildActionButton(
                                  Icons.share_outlined,
                                  "Share",
                                  AppTheme.textSecondary,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<List<CommentModel>>(
                    stream: postsProvider.getCommentsStream(postId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Failed to load comments. Please try again.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final comments = snapshot.data ?? [];

                      if (comments.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.comment_outlined,
                                  size: 64,
                                  color: AppTheme.textTertiary,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  "No comments yet",
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return _buildCommentItem(comment, postModel, postsProvider, authProvider);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Comment Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
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
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: const TextStyle(color: AppTheme.textTertiary),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
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
                      if (_commentController.text.isNotEmpty) {
                        final user = authProvider.currentUser;
                        if (user != null) {
                          await postsProvider.addComment(
                            postId: postId,
                            userId: user.uid,
                            userName: user.name,
                            userAvatarUrl: user.avatarUrl,
                            text: _commentController.text,
                          );
                          _commentController.clear();
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
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String label,
    Color color,
    bool isActive,
    VoidCallback onTap, {
    VoidCallback? onLongPress,
  }) {
    return Expanded(
      child: AnimatedBuilder(
        animation: AlwaysStoppedAnimation(0),
        builder: (context, child) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: BorderRadius.circular(16),
              splashColor: color.withOpacity(0.1),
              highlightColor: color.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isActive ? color.withOpacity(0.15) : Colors.transparent,
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

  Widget _buildCommentItem(CommentModel comment, PostModel post, PostsProvider postsProvider, AuthProvider authProvider) {
    final currentUserId = authProvider.userId;
    final isOwner = currentUserId == comment.userId;
    final isLiked = comment.likedBy.contains(currentUserId);

    return StreamBuilder<List<CommentModel>>(
      stream: postsProvider.getCommentRepliesStream(comment.id),
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
                  GestureDetector(
                    onTap: () => _navigateToProfile(comment.userId),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundImage: comment.userAvatarUrl != null
                          ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                          : null,
                      child: comment.userAvatarUrl == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onLongPress: isOwner ? () => _showCommentOptions(context, comment, post.id, postsProvider) : null,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textMain,
                                    ),
                                  ),
                                ),
                                if (isOwner)
                                  GestureDetector(
                                    onTap: () => _showCommentOptions(context, comment, post.id, postsProvider),
                                    child: const Icon(Icons.more_horiz, size: 16, color: AppTheme.textTertiary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              comment.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.textMain,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  comment.formattedTime,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textTertiary,
                                  ),
                                ),
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
                                      color: isLiked ? AppTheme.primary : AppTheme.textTertiary,
                                    ),
                                  ),
                                ),
                                if (comment.likesCount > 0) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.thumb_up, size: 10, color: AppTheme.primary),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${comment.likesCount}',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    _showReplyDialog(comment, post, postsProvider, authProvider);
                                  },
                                  child: const Text(
                                    'Reply', 
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textTertiary)
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
              // عرض الردود
              if (replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 50, top: 8),
                  child: Column(
                    children: replies.map((reply) {
                      final isReplyOwner = currentUserId == reply.userId;
                      final isReplyLiked = reply.likedBy.contains(currentUserId);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => _navigateToProfile(reply.userId),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: reply.userAvatarUrl != null
                                    ? CachedNetworkImageProvider(reply.userAvatarUrl!)
                                    : null,
                                child: reply.userAvatarUrl == null
                                    ? const Icon(Icons.person, size: 14)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: GestureDetector(
                                onLongPress: isReplyOwner ? () => _showCommentOptions(context, reply, post.id, postsProvider) : null,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceVariant.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              reply.userName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: AppTheme.textMain,
                                              ),
                                            ),
                                          ),
                                          if (isReplyOwner)
                                            GestureDetector(
                                              onTap: () => _showCommentOptions(context, reply, post.id, postsProvider),
                                              child: const Icon(Icons.more_horiz, size: 16, color: AppTheme.textTertiary),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        reply.text,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textMain,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            reply.formattedTime,
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                          ),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () {
                                              if (currentUserId != null) {
                                                postsProvider.toggleCommentLike(reply.id, currentUserId);
                                              }
                                            },
                                            child: Text(
                                              'Like',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isReplyLiked ? AppTheme.primary : AppTheme.textTertiary,
                                              ),
                                            ),
                                          ),
                                          if (reply.likesCount > 0) ...[
                                            const SizedBox(width: 4),
                                            const Icon(Icons.thumb_up, size: 10, color: AppTheme.primary),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${reply.likesCount}',
                                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
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

  void _showCommentOptions(BuildContext context, CommentModel comment, String postId, PostsProvider postsProvider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withOpacity(0.3),
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
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              ),
              title: const Text("Edit Comment", style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primary)),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () {
                Navigator.pop(context);
                postsProvider.deleteComment(comment.id, postId, comment.parentCommentId);
              },
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Comment'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: "Update your comment...",
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

  void _showReplyDialog(CommentModel comment, PostModel post, PostsProvider postsProvider, AuthProvider authProvider) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${comment.userName}'),
        content: TextField(
          controller: replyCtrl,
          decoration: InputDecoration(
            hintText: 'Write a reply...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(this.context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (replyCtrl.text.isNotEmpty) {
                final user = authProvider.currentUser;
                if (user != null) {
                  await postsProvider.addComment(
                    postId: post.id,
                    userId: user.uid,
                    userName: user.name,
                    userAvatarUrl: user.avatarUrl,
                    text: replyCtrl.text,
                    parentCommentId: comment.id,
                  );
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                }
              }
            },
            child: const Text('Reply'),
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
    if (_streams.containsKey(url)) return;
    final provider = CachedNetworkImageProvider(url);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        final ratio = (w / h).clamp(0.75, 1.65);
        if (mounted) setState(() => _ratios[url] = ratio);
      }
      stream.removeListener(listener);
      _streams.remove(url);
      _listeners.remove(url);
    }, onError: (_, __) {
      stream.removeListener(listener);
      _streams.remove(url);
      _listeners.remove(url);
    });
    _streams[url] = stream;
    _listeners[url] = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    for (final entry in _streams.entries) {
      final l = _listeners[entry.key];
      if (l != null) entry.value.removeListener(l);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return const SizedBox.shrink();

    final safeIndex = _index.clamp(0, urls.length - 1);
    final currentUrl = urls[safeIndex];
    _resolveRatio(currentUrl);
    final ratio = _ratios[currentUrl] ?? 4 / 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = (width / ratio).clamp(widget.minHeight, widget.maxHeight);
        return ClipRRect(
          borderRadius: widget.borderRadius,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: height,
            width: double.infinity,
            color: AppTheme.surfaceVariant,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: urls.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final url = urls[i];
                    _resolveRatio(url);
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Image(
                          image: CachedNetworkImageProvider(url),
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) => const Center(child: Icon(Icons.broken_image_rounded)),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FullscreenImagesPage(urls: urls, initialIndex: i),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (urls.length > 1)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${safeIndex + 1}/${urls.length}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                if (urls.length > 1)
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(urls.length, (i) {
                        final active = i == safeIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 12 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(active ? 0.95 : 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
