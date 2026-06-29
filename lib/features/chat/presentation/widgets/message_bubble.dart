import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/reactions_bar.dart';
import 'package:project_test2/features/chat/presentation/widgets/voice_message_player.dart';
import 'package:project_test2/features/chat/presentation/widgets/reactions_bottom_sheet.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
=======
import '../../../../core/theme.dart';
import '../../domain/entities/message_entity.dart';
import '../../../../features/community/presentation/widgets/reactions_bar.dart';
import 'voice_message_player.dart';
import 'reactions_bottom_sheet.dart';
import '../../../../features/profile/user_profile_screen.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final bool isDark;
  final bool showAvatar;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isSelected;
  final String currentUserId;
  final bool enableReactions;
  final bool compact;
  
  // Callbacks
  final VoidCallback? onLongPress;
  final void Function(MessageEntity)? onReply;
  final void Function(MessageEntity)? onEdit;
  final void Function(MessageEntity, bool)? onDelete; // bool = forEveryone
  final void Function(MessageEntity, String)? onReact;
  final void Function(MessageEntity)? onCopy;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.isDark,
    required this.showAvatar,
    required this.otherUserName,
    required this.currentUserId,
    this.otherUserAvatar,
    this.isSelected = false,
    this.enableReactions = true,
    this.compact = false,
    this.onLongPress,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isDeletedForUser(currentUserId)) {
      if (message.deletedForAll) {
        return _DeletedBubble(isMe: isMe, compact: compact);
      }
      return const SizedBox.shrink();
    }

    final bubbleColor = isMe
        ? AppTheme.primary
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;

    final horizontalInset = compact ? 54.0 : 64.0;
    final bubblePadding = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 6)
        : const EdgeInsets.fromLTRB(12, 12, 12, 8);

    return RepaintBoundary(
      child: GestureDetector(
        onLongPress: () {
        HapticFeedback.mediumImpact();
        onLongPress?.call();
        _showContextMenu(context);
      },
      onDoubleTap: enableReactions
          ? () {
              HapticFeedback.lightImpact();
              onReact?.call(message, '❤️');
            }
          : null,
      child: ExcludeSemantics(
        child: Dismissible(
          key: ValueKey('dismiss_${message.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            onReply?.call(message);
            return false;
          },
          background: const SizedBox.shrink(),
          secondaryBackground: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.reply_rounded,
                  color: AppTheme.primary.withValues(alpha: 0.6)),
            ),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            padding: EdgeInsets.only(
              left: isMe ? horizontalInset : 8,
              right: isMe ? 8 : horizontalInset,
              top: compact ? 1 : 2,
              bottom: compact ? 1 : 2,
            ),
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  SizedBox(
                    width: compact ? 28 : 32,
                    child: showAvatar
                        ? _MiniAvatar(
                            name: otherUserName,
                            avatarUrl: otherUserAvatar,
                            compact: compact,
                          )
                        : const SizedBox(),
                  ),
                  SizedBox(width: compact ? 6 : 8),
                ],
                Flexible(
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              gradient: isMe ? AppTheme.primaryGradient : null,
                              color: bubbleColor,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: isMe
                                    ? const Radius.circular(18)
                                    : const Radius.circular(4),
                                bottomRight: isMe
                                    ? const Radius.circular(4)
                                    : const Radius.circular(18),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                      alpha: isDark ? 0.2 : 0.06),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: bubblePadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (message.replyToMessageId != null)
                                  _ReplyPreview(
                                    text: message.replyToText ?? '',
                                    senderName:
                                        message.replyToSenderName ?? '',
                                    isMe: isMe,
                                  ),
                                if (message.mediaUrls.isNotEmpty &&
                                    message.messageType !=
                                        ChatMessageType.audio)
                                  _MediaContent(
                                      urls: message.mediaUrls,
                                      type: message.messageType,
                                      isMe: isMe),
                                if (message.messageType ==
                                        ChatMessageType.audio &&
                                    message.mediaUrls.isNotEmpty)
                                  VoiceMessagePlayer(
                                    audioUrl: message.mediaUrls.first,
                                    durationSeconds: message.audioDuration ?? 0,
                                    isMe: isMe,
                                    isDark: isDark,
                                    compact: compact,
                                  ),
                                if (message.messageType ==
                                        ChatMessageType.audio &&
                                    message.mediaUrls.isEmpty &&
                                    message.audioUrl != null)
                                  VoiceMessagePlayer(
                                    audioUrl: message.audioUrl!,
                                    durationSeconds: message.audioDuration ?? 0,
                                    isMe: isMe,
                                    isDark: isDark,
                                    compact: compact,
                                  ),
                                if (message.messageType ==
                                        ChatMessageType.audio &&
                                    message.mediaUrls.isEmpty &&
                                    message.audioUrl == null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.mic_rounded,
                                          size: compact ? 16 : 18,
                                          color: isMe
                                              ? Colors.white70
                                              : AppTheme.primary,
                                        ),
                                        SizedBox(width: compact ? 6 : 8),
                                        Text(
                                          'Uploading...',
                                          style: TextStyle(
                                            color: textColor.withValues(alpha: 0.85),
                                            fontSize: compact ? 12 : 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (message.text.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      message.text,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: compact ? 14 : 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (message.isEdited)
                                      Text(
                                        'edited · ',
                                        style: TextStyle(
                                          fontSize: compact ? 9 : 10,
                                          color: isMe
                                              ? Colors.white60
                                              : Colors.black38,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    Text(
                                      DateFormat.jm()
                                          .format(message.createdAt),
                                      style: TextStyle(
                                        fontSize: compact ? 9 : 10,
                                        color: isMe
                                            ? Colors.white60
                                            : Colors.black38,
                                      ),
                                    ),
                                    if (isMe) ...[
                                      const SizedBox(width: 4),
                                      _StatusIcon(
                                        status: message.status,
                                        compact: compact,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (enableReactions && message.reactions.isNotEmpty)
                            Positioned(
                              bottom: -8,
                              right: isMe ? 8 : null,
                              left: isMe ? null : 8,
                              child: ReactionsRow(
                                reactions: message.reactions,
                                currentUserId: currentUserId,
                                onTap: (_) => _showReactionsDetails(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _showReactionsDetails(BuildContext context) {
    if (!enableReactions || message.reactions.isEmpty) return;
    HapticFeedback.lightImpact();
    final usersData = message.reactions.keys.map((uid) {
      if (uid == currentUserId) {
         return ReactionUserData(id: uid, name: 'You');
      } else {
         return ReactionUserData(id: uid, name: otherUserName, avatarUrl: otherUserAvatar);
      }
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReactionsBottomSheet(
         reactions: message.reactions,
         currentUserId: currentUserId,
         usersData: usersData,
         onUserTapped: (uid) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(userId: uid),
              ),
            );
         },
         onToggleReaction: (emoji) {
            Navigator.pop(context);
            onReact?.call(message, emoji);
         },
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    // In 1-on-1, you can only delete for everyone if you are the sender
    // within the time limit. Let's say 10 minutes (matching group chat cutoff).
    final canDeleteForAll = isMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextMenu(
        message: message,
        isMe: isMe,
        canDeleteForAll: canDeleteForAll,
        currentUserReaction: message.reactions[currentUserId],
        enableReactions: enableReactions,
        onReply: () {
          Navigator.pop(context);
          onReply?.call(message);
        },
        onEdit: isMe
            ? () {
                Navigator.pop(context);
                onEdit?.call(message);
              }
            : null,
        onDeleteForMe: () {
          Navigator.pop(context);
          onDelete?.call(message, false);
        },
        onDeleteForAll: canDeleteForAll
            ? () {
                Navigator.pop(context);
                onDelete?.call(message, true);
              }
            : null,
        onReact: (emoji) {
          Navigator.pop(context);
          if (!enableReactions) return;
          onReact?.call(message, emoji);
        },
        onCopy: () {
          Navigator.pop(context);
          onCopy?.call(message);
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }
}

// ── Status tick icon ─────────────────────────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  final MessageStatus status;
  final bool compact;
  const _StatusIcon({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 12.0 : 14.0;
    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: compact ? 11 : 12,
          height: compact ? 11 : 12,
          child: CircularProgressIndicator(
            strokeWidth: compact ? 1.4 : 1.5,
            color: Colors.white60,
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.done_rounded,
          size: iconSize,
          color: Colors.white60,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all_rounded,
          size: iconSize,
          color: Colors.white60,
        );
      case MessageStatus.seen:
        return Icon(
          Icons.done_all_rounded,
          size: iconSize,
          color: Colors.blue,
        );
    }
  }
}

// ── Mini avatar ───────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool compact;
  const _MiniAvatar({required this.name, this.avatarUrl, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final url = (avatarUrl ?? '').trim();
    return CircleAvatar(
      radius: compact ? 14 : 16,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      backgroundImage:
          url.isNotEmpty ? CachedNetworkImageProvider(url) : null,
      child: url.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            )
          : null,
    );
  }
}

class _ReplyPreview extends StatelessWidget {
  final String text;
  final String senderName;
  final bool isMe;
  const _ReplyPreview(
      {required this.text, required this.senderName, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : AppTheme.primary,
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isMe ? Colors.white70 : AppTheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text.isEmpty ? 'Media' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaContent extends StatelessWidget {
  final List<String> urls;
  final ChatMessageType type;
  final bool isMe;
  const _MediaContent({required this.urls, required this.type, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (type == ChatMessageType.image && urls.isNotEmpty) {
      final url = urls.first;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              opaque: false,
              barrierColor: Colors.black87,
              pageBuilder: (_, __, ___) => _FullscreenImageViewer(url: url),
            ),
          ),
          child: Hero(
            tag: url,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                width: 240,
<<<<<<< HEAD
                memCacheWidth: 480,
=======
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
                placeholder: (_, __) => Container(
                  width: 240,
                  height: 160,
                  color: Colors.black12,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 240,
                  height: 120,
                  color: Colors.black12,
                  child: const Icon(Icons.broken_image_rounded,
                      color: Colors.white54, size: 40),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          type == ChatMessageType.audio
              ? Icons.audiotrack_rounded
              : Icons.attach_file_rounded,
          size: 20,
          color: isMe ? Colors.white70 : Colors.black54,
        ),
        const SizedBox(width: 6),
        Text(
          type == ChatMessageType.audio ? 'Voice message' : 'Attachment',
          style: TextStyle(fontSize: 13, color: isMe ? Colors.white70 : Colors.black54),
        ),
      ],
    );
  }
}

/// Full-screen image viewer with hero animation and close button
class _FullscreenImageViewer extends StatelessWidget {
  final String url;
  const _FullscreenImageViewer({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on tap outside
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.black87),
          ),
          // Image
          Center(
            child: Hero(
              tag: url,
              child: InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // Close button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  final bool compact;
  const _DeletedBubble({required this.isMe, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? (compact ? 54 : 64) : 8,
        right: isMe ? 8 : (compact ? 54 : 64),
        top: compact ? 1 : 2,
        bottom: compact ? 1 : 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 14,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'This message was deleted',
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextMenu extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final bool canDeleteForAll;
  final String? currentUserReaction;
  final bool enableReactions;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForAll;
  final void Function(String emoji) onReact;
  final VoidCallback onCopy;

  const _ContextMenu({
    required this.message,
    required this.isMe,
    required this.canDeleteForAll,
    required this.currentUserReaction,
    required this.enableReactions,
    required this.onReply,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForAll,
    required this.onReact,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2235) : Colors.white;
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.05);

    final emojis = ['❤️', '👍', '😂', '😮', '😢'];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              if (enableReactions) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: emojis.map((emoji) {
                      final isSelected = currentUserReaction == emoji;
                      return GestureDetector(
                        onTap: () => onReact(emoji),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 1.0, end: isSelected ? 1.3 : 1.0),
                          duration: const Duration(milliseconds: 200),
                          builder: (_, scale, child) =>
                              Transform.scale(scale: scale, child: child),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(emoji,
                                      style: const TextStyle(fontSize: 30)),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Actions Menu ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PremiumMenuItem(
                      icon: Icons.reply_rounded,
                      label: 'Reply',
                      iconBg: const Color(0xFF3B82F6),
                      onTap: onReply,
                    ),
                    Divider(height: 1, color: divColor),
                    if (message.text.isNotEmpty) ...[
                      _PremiumMenuItem(
                        icon: Icons.copy_rounded,
                        label: 'Copy',
                        iconBg: const Color(0xFF8B5CF6),
                        onTap: onCopy,
                      ),
                      Divider(height: 1, color: divColor),
                    ],
                    if (onEdit != null) ...[
                      _PremiumMenuItem(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        iconBg: const Color(0xFFF59E0B),
                        onTap: onEdit!,
                      ),
                      Divider(height: 1, color: divColor),
                    ],
                    if (onDeleteForAll != null) ...[
                      _PremiumMenuItem(
                        icon: Icons.delete_sweep_rounded,
                        label: 'Delete for Everyone',
                        iconBg: AppTheme.error,
                        labelColor: AppTheme.error,
                        onTap: onDeleteForAll!,
                      ),
                      Divider(height: 1, color: divColor),
                    ],
                    _PremiumMenuItem(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete for Me',
                      iconBg: AppTheme.error.withValues(alpha: 0.7),
                      labelColor: AppTheme.error,
                      onTap: onDeleteForMe,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconBg;
  final Color? labelColor;
  final VoidCallback onTap;
  final bool isLast;

  const _PremiumMenuItem({
    required this.icon,
    required this.label,
    required this.iconBg,
    required this.onTap,
    this.labelColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = labelColor ??
        (isDark ? Colors.white : const Color(0xFF1E293B));

    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(18))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
