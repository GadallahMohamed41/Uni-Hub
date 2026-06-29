import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme.dart';
import '../../../core/reactions.dart';
import '../../../core/app_snackbar.dart';
import '../../../models/post_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/posts_provider.dart';
import 'media_widgets.dart';
import 'reactions_bottom_sheet.dart';
import '../../../widgets/custom_confirm_dialog.dart';
import '../../profile/user_profile_screen.dart';
import '../../profile/profile_screen.dart';
class PostCard extends StatelessWidget {
  final PostModel post;
  final void Function(PostModel) onShowComment;
  final void Function(PostModel) onShowRepost;
  final void Function(PostModel, Offset) onShowReactionPicker;
  final void Function(String userId)? onUserTap;  

   final String? currentProfileUserId;

  const PostCard({
    super.key,
    required this.post,
    required this.onShowComment,
    required this.onShowRepost,
    required this.onShowReactionPicker,
    this.onUserTap, 
    this.currentProfileUserId,  
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);
    final isAdmin = context.select<AuthProvider, bool>((auth) => auth.currentUser?.isAdmin == true);
    final isLiked = userId != null && post.isLikedByUser(userId);
    final isLaughed = userId != null && post.isLaughedByUser(userId);
    final isSupported = userId != null && post.isSupportedByUser(userId);
    final currentReaction = isLaughed
        ? ReactionType.laugh
        : (isSupported
            ? ReactionType.support
            : (isLiked ? ReactionType.like : null));
    final reactIcon = ReactionUi.iconFor(currentReaction);
    final reactLabel = ReactionUi.labelFor(currentReaction);
    final reactColor = ReactionUi.colorFor(currentReaction);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

     void navigateToProfile(String targetUserId) {
       if (onUserTap != null) {
        onUserTap!(targetUserId);
        return;
      }

        if (currentProfileUserId == targetUserId) {
         return;
      }

      if (targetUserId == userId) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const ProfileScreen()),
        );
        return;
      }

       Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UserProfileScreen(userId: targetUserId)),
      );
    }

    return RepaintBoundary(
      child: GestureDetector(
        onLongPressStart: (d) => onShowReactionPicker(post, d.globalPosition),
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: () {
                  navigateToProfile(post.userId);
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      width: 1.5,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: post.userAvatarUrl != null
                        ? CachedNetworkImageProvider(post.userAvatarUrl!)
                        : null,
                    child: post.userAvatarUrl == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        navigateToProfile(post.userId);
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              post.userName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.feeling != null && post.feeling!.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'is feeling ${post.feeling}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      post.userBio,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          post.formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          post.privacyLevel == 'friends'
                              ? Icons.people_rounded
                              : (post.privacyLevel == 'only_me'
                                  ? Icons.lock_rounded
                                  : Icons.public_rounded),
                          size: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (post.userId == userId || isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppTheme.error),
                          SizedBox(width: 8),
                          Text('Delete Post'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value != 'delete') return;
                    await CustomConfirmDialog.show(
                      context,
                      title: 'Delete Post',
                      content: 'Are you sure you want to delete this post?',
                      confirmLabel: 'Delete',
                      confirmColor: AppTheme.error,
                      icon: Icons.delete_forever_rounded,
                      onConfirm: () async {
                        try {
                          final postsProvider = context.read<PostsProvider>();
                          final ok = await postsProvider.deletePost(
                              post.id, post.imageUrls);
                          if (context.mounted) {
                            if (ok) {
                              AppSnackBar.showSuccess(
                                  context, 'Post deleted successfully');
                            } else {
                              AppSnackBar.showError(
                                  context,
                                  postsProvider.error ??
                                      'Failed to delete post');
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackBar.showError(
                                context, 'Failed to delete post: $e');
                          }
                        }
                      },
                    );
                  },
                ),
            ]),
          ),
          if (post.repostOf != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppTheme.surfaceVariant,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Repost from ${post.originalUserName ?? 'User'}",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if ((post.originalText ?? '').isNotEmpty)
                      Text(
                        post.originalText!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    if (post.originalImageUrl != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullscreenImagesPage(
                                    urls: [post.originalImageUrl!],
                                    initialIndex: 0),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: post.originalImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (post.text.isNotEmpty && post.repostOf == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                post.text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          if (post.videoUrl != null && post.repostOf == null)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: InlineVideo(url: post.videoUrl!, fit: BoxFit.fill))
          else if (post.imageUrls.isNotEmpty && post.repostOf == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AdaptiveMediaCarousel(
                  urls: post.imageUrls,
                  minHeight: 200,
                  maxHeight: 500,
                  borderRadius: BorderRadius.circular(12)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Row(
              children: [
                if (post.totalReactions > 0)
                  GestureDetector(
                    onTap: () => showPostReactionsSheet(context, post),
                    child: Row(
                      children: [
                        if (post.likesCount > 0)
                          Row(
                            children: [
                              const Text("👍", style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 3),
                              Text(
                                "${post.likesCount}",
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        if (post.laughedCount > 0) ...[
                          const SizedBox(width: 5),
                          const Text("😂", style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            "${post.laughedCount}",
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                        if (post.supportedCount > 0) ...[
                          const SizedBox(width: 5),
                          const Text("❤️", style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 3),
                          Text(
                            "${post.supportedCount}",
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.65),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => onShowComment(post),
                  child: Text(
                    "${post.commentsCount} comments",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppTheme.surfaceVariant,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.cardTheme.color ?? theme.colorScheme.surface,
                    (theme.cardTheme.color ?? theme.colorScheme.surface)
                        .withValues(alpha: 0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                _reactionBtn(context, reactIcon, reactLabel, reactColor, () {
                  if (userId == null) return;
                  final postsProvider = context.read<PostsProvider>();
                  if (isLaughed) {
                    postsProvider.toggleLaugh(post.id, userId);
                    return;
                  }
                  if (isSupported) {
                    postsProvider.toggleSupport(post.id, userId);
                    return;
                  }
                  postsProvider.toggleLike(post.id, userId);
                }, onLongPressStart: (pos) => onShowReactionPicker(post, pos)),
                _actionBtn(Icons.comment_outlined, "Comment", AppTheme.info,
                    () => onShowComment(post)),
                _actionBtn(Icons.repeat_rounded, "Repost", AppTheme.warning,
                    () => onShowRepost(post)),
              ]),
            ),
          ),
        ]),
      ),
    ),
  );
}

  Widget _actionBtn(
      IconData icon, String label, Color color, VoidCallback onTap,
      {VoidCallback? onLongPress}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          splashColor: color.withValues(alpha: 0.08),
          highlightColor: color.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16)),
              const SizedBox(height: 3),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _reactionBtn(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    required void Function(Offset globalPosition) onLongPressStart,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (d) => onLongPressStart(d.globalPosition),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: color.withValues(alpha: 0.08),
            highlightColor: color.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
