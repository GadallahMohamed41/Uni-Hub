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

class PostCard extends StatelessWidget {
  final PostModel post;
  final void Function(PostModel) onShowComment;
  final void Function(PostModel) onShowRepost;
  final void Function(PostModel) onShowReactionPicker;
  const PostCard({super.key, required this.post, required this.onShowComment, required this.onShowRepost, required this.onShowReactionPicker});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final postsProvider = context.watch<PostsProvider>();
    final userId = authProvider.userId;
    final isLiked = userId != null && post.isLikedByUser(userId);
    final isLaughed = userId != null && post.isLaughedByUser(userId);
    final isSupported = userId != null && post.isSupportedByUser(userId);
    final currentReaction = isLaughed ? ReactionType.laugh : (isSupported ? ReactionType.support : (isLiked ? ReactionType.like : null));
    final reactIcon = ReactionUi.iconFor(currentReaction);
    final reactLabel = ReactionUi.labelFor(currentReaction);
    final reactColor = ReactionUi.colorFor(currentReaction);

    return GestureDetector(
      onLongPress: () => onShowReactionPicker(post),
      child: Container(
        decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primary.withOpacity(0.1), width: 2)),
                child: CircleAvatar(radius: 26, backgroundImage: post.userAvatarUrl != null ? CachedNetworkImageProvider(post.userAvatarUrl!) : null, child: post.userAvatarUrl == null ? const Icon(Icons.person, size: 26) : null),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(post.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppTheme.textMain)),
                  const SizedBox(height: 4),
                  Text(post.userBio, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(post.formattedTime, style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                ]),
              ),
              if (post.userId == userId || (authProvider.currentUser?.isAdmin == true))
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_horiz, color: AppTheme.textTertiary),
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete_outline, color: AppTheme.error), SizedBox(width: 8), Text('Delete Post')]),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value != 'delete') return;
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Post'),
                        content: const Text('Are you sure you want to delete this post?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    final ok = await postsProvider.deletePost(post.id, post.imageUrls);
                    if (!context.mounted) return;
                    if (ok) {
                      AppSnackBar.showSuccess(context, 'Post deleted');
                    } else {
                      AppSnackBar.showError(context, postsProvider.error ?? 'Failed to delete post');
                    }
                  },
                ),
            ]),
          ),
          if (post.repostOf != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.surfaceVariant)),
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Repost from ${post.originalUserName ?? 'User'}", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  if ((post.originalText ?? '').isNotEmpty) Text(post.originalText!, style: const TextStyle(fontSize: 14, color: AppTheme.textMain)),
                  if (post.originalImageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FullscreenImagesPage(urls: [post.originalImageUrl!], initialIndex: 0),
                            ),
                          );
                        },
                        child: CachedNetworkImage(imageUrl: post.originalImageUrl!, width: double.infinity, fit: BoxFit.cover),
                      ),
                    ),
                ]),
              ),
            ),
          if (post.text.isNotEmpty && post.repostOf == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(post.text, style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textMain)),
            ),
          if (post.videoUrl != null && post.repostOf == null)
            Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 0), child: InlineVideo(url: post.videoUrl!, fit: BoxFit.fill))
          else if (post.imageUrls.isNotEmpty && post.repostOf == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: AdaptiveMediaCarousel(urls: post.imageUrls, minHeight: 180, maxHeight: 320, borderRadius: BorderRadius.circular(18)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(children: [
              if (post.totalReactions > 0)
                GestureDetector(
                  onTap: () => showPostReactionsSheet(context, post),
                  child: Row(children: [
                  if (post.likesCount > 0) Row(children: [const Text("👍", style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text("${post.likesCount}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))]),
                  if (post.laughedCount > 0) ...[const SizedBox(width: 8), const Text("😂", style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text("${post.laughedCount}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))],
                  if (post.supportedCount > 0) ...[const SizedBox(width: 8), const Text("❤️", style: TextStyle(fontSize: 14)), const SizedBox(width: 4), Text("${post.supportedCount}", style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))],
                  ]),
                ),
              const Spacer(),
              Text("${post.commentsCount} comments", style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
          Divider(height: 1, color: AppTheme.surfaceVariant),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [AppTheme.surface, AppTheme.surface.withOpacity(0.5)]), borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                _actionBtn(reactIcon, reactLabel, reactColor, () {
                  if (userId == null) return;
                  if (isLaughed) {
                    postsProvider.toggleLaugh(post.id, userId);
                    return;
                  }
                  if (isSupported) {
                    postsProvider.toggleSupport(post.id, userId);
                    return;
                  }
                  postsProvider.toggleLike(post.id, userId);
                }, onLongPress: () => onShowReactionPicker(post)),
                _actionBtn(Icons.comment_outlined, "Comment", AppTheme.info, () => onShowComment(post)),
                _actionBtn(Icons.repeat_rounded, "Repost", AppTheme.warning, () => onShowRepost(post)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap, {VoidCallback? onLongPress}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withOpacity(0.1),
          highlightColor: color.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
              const SizedBox(height: 5),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}
