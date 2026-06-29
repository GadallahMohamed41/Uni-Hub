import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/home/data/models/comment_model.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/profile_screen.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────
void showCommentsSheet(BuildContext context, PostModel post) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsSheet(post: post),
  );
}

class CommentsSheet extends StatefulWidget {
  final PostModel post;
  const CommentsSheet({super.key, required this.post});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  final ScrollController _scroll = ScrollController();

  // Reply state
  CommentModel? _replyingTo; // null = top-level comment

  // Edit state
  CommentModel? _editingComment;

  late final Stream<List<CommentModel>> _commentsStream;

  @override
  void initState() {
    super.initState();
    _commentsStream = context
        .read<PostsProvider>()
        .getPostCommentsThreadStream(widget.post.id);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _startReply(CommentModel comment) {
    setState(() {
      _replyingTo = comment;
      _editingComment = null;
      _ctrl.text = '';
    });
    _focus.requestFocus();
  }

  void _startEdit(CommentModel comment) {
    setState(() {
      _editingComment = comment;
      _replyingTo = null;
      _ctrl.text = comment.text;
    });
    _focus.requestFocus();
  }

  void _cancelAction() {
    setState(() {
      _replyingTo = null;
      _editingComment = null;
      _ctrl.text = '';
    });
    _focus.unfocus();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final auth = context.read<AuthProvider>();
    final posts = context.read<PostsProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    _ctrl.clear();

    if (_editingComment != null) {
      await posts.updateComment(_editingComment!.id, text);
      setState(() => _editingComment = null);
      return;
    }

    await posts.addComment(
      postId: widget.post.id,
      userId: user.uid,
      userName: user.name,
      userAvatarUrl: user.avatarUrl,
      text: text,
      parentCommentId: _replyingTo?.parentCommentId ?? _replyingTo?.id,
      mentionedUserIds: _replyingTo != null ? [_replyingTo!.userId] : null,
    );

    setState(() => _replyingTo = null);

    await Future.delayed(const Duration(milliseconds: 300));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height * 0.88;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Handle ──
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),

              // ── Post blurred image header ──
              if (widget.post.imageUrls.isNotEmpty)
                _BlurredPostHeader(imageUrl: widget.post.imageUrls.first),

              // ── Title ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_outlined,
                        color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    // Count badge – count top-level only
                    StreamBuilder<List<CommentModel>>(
                      stream: _commentsStream,
                      builder: (_, snap) {
                        final all = snap.data ?? [];
                        final topCount =
                            all.where((c) => c.parentCommentId == null).length;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$topCount',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.grey.withValues(alpha: 0.1)),

              // ── Comments list using FULL thread stream (includes replies) ──
              Expanded(
                child: StreamBuilder<List<CommentModel>>(
                  stream: _commentsStream,
                  builder: (_, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final all = snap.data ?? [];
                    // Top-level only
                    final topLevel =
                        all.where((c) => c.parentCommentId == null).toList();

                    if (topLevel.isEmpty) {
                      return _EmptyComments();
                    }

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: topLevel.length,
                      itemBuilder: (_, i) {
                        final comment = topLevel[i];
                        // Replies for this comment
                        final replies = all
                            .where((c) => c.parentCommentId == comment.id)
                            .toList();

                        return _CommentThread(
                          comment: comment,
                          replies: replies,
                          postId: widget.post.id,
                          onReply: _startReply,
                          onEdit: _startEdit,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Reply/Edit indicator ──
              if (_replyingTo != null || _editingComment != null)
                _ActionBanner(
                  replyingTo: _replyingTo,
                  editing: _editingComment,
                  onCancel: _cancelAction,
                ),

              // ── Input ──
              _CommentInput(
                controller: _ctrl,
                focusNode: _focus,
                onSubmit: _submit,
                isEditing: _editingComment != null,
              ),

              SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Blurred post image header
// ═══════════════════════════════════════════════════════════════════════════════
class _BlurredPostHeader extends StatelessWidget {
  final String imageUrl;
  const _BlurredPostHeader({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: SizedBox(
        height: 80,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Blurred background
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),
            // Sharp image centered
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 60,
                  width: 60,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comment Thread (top-level + replies)
// ═══════════════════════════════════════════════════════════════════════════════
class _CommentThread extends StatefulWidget {
  final CommentModel comment;
  final List<CommentModel> replies;
  final String postId;
  final void Function(CommentModel) onReply;
  final void Function(CommentModel) onEdit;

  const _CommentThread({
    required this.comment,
    required this.replies,
    required this.postId,
    required this.onReply,
    required this.onEdit,
  });

  @override
  State<_CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<_CommentThread> {
  bool _showReplies = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CommentBubble(
          key: ValueKey(widget.comment.id),
          comment: widget.comment,
          postId: widget.postId,
          isReply: false,
          onReply: () => widget.onReply(widget.comment),
          onEdit: () => widget.onEdit(widget.comment),
        ),

        // Replies count toggle
        if (widget.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52, bottom: 4),
            child: GestureDetector(
              onTap: () => setState(() => _showReplies = !_showReplies),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 1,
                    color: AppTheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showReplies
                        ? 'Hide replies'
                        : '${widget.replies.length} ${widget.replies.length == 1 ? 'reply' : 'replies'}',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _showReplies
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

        // Replies
        if (_showReplies)
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Column(
              children: widget.replies.map((r) {
                return _CommentBubble(
                  key: ValueKey(r.id),
                  comment: r,
                  postId: widget.postId,
                  isReply: true,
                  mentionedName: widget.comment.userName,
                  onReply: () => widget.onReply(widget.comment),
                  onEdit: () => widget.onEdit(r),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 6),
      ],
    );
  }
}

// Individual Comment Bubble
class _CommentBubble extends StatefulWidget {
  final CommentModel comment;
  final String postId;
  final bool isReply;
  final String? mentionedName;
  final VoidCallback onReply;
  final VoidCallback onEdit;

  const _CommentBubble({
    super.key,
    required this.comment,
    required this.postId,
    required this.isReply,
    this.mentionedName,
    required this.onReply,
    required this.onEdit,
  });

  @override
  State<_CommentBubble> createState() => _CommentBubbleState();
}

class _CommentBubbleState extends State<_CommentBubble> {
  void _toggleLike() {
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    if (uid == null) return;
    context.read<PostsProvider>().toggleCommentLike(widget.comment.id, uid);
  }

  Future<void> _delete() async {
    final posts = context.read<PostsProvider>();
    await posts.deleteComment(
      widget.comment.id,
      widget.postId,
      widget.comment.parentCommentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    final isOwn = uid == widget.comment.userId;
    final isAdmin = auth.currentUser?.isAdmin ?? false;
    final isLiked = uid != null && widget.comment.likedBy.contains(uid);
    final url = (widget.comment.userAvatarUrl ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop(); // Close bottom sheet
              if (uid == widget.comment.userId) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        UserProfileScreen(userId: widget.comment.userId),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: widget.isReply ? 14 : 18,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
              backgroundImage:
                  url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
              child: url.isEmpty
                  ? Text(
                      widget.comment.userName.isNotEmpty
                          ? widget.comment.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: widget.isReply ? 10 : 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bubble
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(4),
                      topRight: const Radius.circular(16),
                      bottomLeft: const Radius.circular(16),
                      bottomRight: const Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(
                        children: [
                          Text(
                            widget.comment.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: widget.isReply ? 12 : 13,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            widget.comment.formattedTime,
                            style: const TextStyle(
                                fontSize: 10, color: AppTheme.textTertiary),
                          ),
                          if (widget.comment.isEdited)
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                '(edited)',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.textTertiary,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          // Options
                          if (isOwn || isAdmin)
                            GestureDetector(
                              onTap: () => _showOptions(context, isOwn),
                              child: const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(Icons.more_horiz,
                                    size: 16, color: AppTheme.textTertiary),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Mention
                      if (widget.isReply && widget.mentionedName != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '@${widget.mentionedName}',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      // Text
                      Text(
                        widget.comment.text,
                        style: TextStyle(
                          fontSize: widget.isReply ? 12 : 13,
                          height: 1.4,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions row
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Row(
                    children: [
                      // Like btn
                      GestureDetector(
                        onTap: _toggleLike,
                        child: Row(
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 14,
                              color: isLiked
                                  ? AppTheme.error
                                  : AppTheme.textSecondary,
                            ),
                            if (widget.comment.likesCount > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '${widget.comment.likesCount}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isLiked
                                      ? AppTheme.error
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Reply btn
                      GestureDetector(
                        onTap: widget.onReply,
                        child: const Text(
                          'Reply',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context, bool isOwn) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 20),
            if (isOwn) ...[
              _OptionTile(
                icon: Icons.edit_rounded,
                label: 'Edit comment',
                color: AppTheme.info,
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit();
                },
              ),
              const SizedBox(height: 8),
            ],
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Delete comment',
              color: AppTheme.error,
              onTap: () {
                Navigator.pop(context);
                _delete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Action Banner (Replying to / Editing)
// ═══════════════════════════════════════════════════════════════════════════════
class _ActionBanner extends StatelessWidget {
  final CommentModel? replyingTo;
  final CommentModel? editing;
  final VoidCallback onCancel;

  const _ActionBanner({
    required this.replyingTo,
    required this.editing,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = editing != null;
    final label =
        isEdit ? 'Editing comment' : 'Replying to ${replyingTo!.userName}';
    final color = isEdit ? AppTheme.warning : AppTheme.primary;

    return Container(
      color: color.withValues(alpha: isDark ? 0.1 : 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            isEdit ? Icons.edit_rounded : Icons.reply_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            child: Icon(Icons.close_rounded, size: 18, color: color),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Comment Input
// ═══════════════════════════════════════════════════════════════════════════════
class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;
  final bool isEditing;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.isEditing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarUrl = context.select<AuthProvider, String?>((auth) => auth.currentUser?.avatarUrl);
    final url = (avatarUrl ?? '').trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // User avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
            backgroundImage:
                url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
            child: url.isEmpty
                ? const Icon(Icons.person, size: 18, color: AppTheme.primary)
                : null,
          ),
          const SizedBox(width: 10),
          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText:
                      isEditing ? 'Edit your comment...' : 'Write a comment...',
                  hintStyle: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.newline,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: onSubmit,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                isEditing ? Icons.check_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Empty state
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyComments extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mode_comment_outlined,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No comments yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to comment!',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
