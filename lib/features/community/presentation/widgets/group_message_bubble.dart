import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';
import 'package:project_test2/features/community/presentation/widgets/reactions_bar.dart';
import 'package:project_test2/features/chat/presentation/widgets/voice_message_player.dart';
import 'package:project_test2/features/chat/presentation/widgets/reactions_bottom_sheet.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/community/domain/entities/group_member_entity.dart';

/// Full WhatsApp-style message bubble for group chat.
class GroupMessageBubble extends StatelessWidget {
  final GroupMessageEntity message;
  final bool isMe;
  final bool showSenderInfo; // hide if same sender as previous
  final String currentUserId;
  final bool isAdmin;
  final List<GroupMemberEntity>? members;

  // Callbacks
  final void Function(GroupMessageEntity)? onReply;
  final void Function(GroupMessageEntity)? onEdit;
  final void Function(GroupMessageEntity, bool)? onDelete; // bool = forEveryone
  final void Function(GroupMessageEntity)? onInfo;
  final void Function(GroupMessageEntity, String)? onReact;
  final void Function(GroupMessageEntity)? onPin;
  final void Function(GroupMessageEntity)? onForward;
  final void Function(GroupMessageEntity)? onPlayAudio;

  const GroupMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.showSenderInfo,
    required this.currentUserId,
    required this.isAdmin,
    this.members,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onInfo,
    this.onReact,
    this.onPin,
    this.onForward,
    this.onPlayAudio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If deleted for this user, show placeholder
    if (message.isDeletedForUser(currentUserId)) {
      return _DeletedBubble(isMe: isMe);
    }

    // System message (group created, user joined, etc.)
    if (message.messageType == GroupMessageType.system) {
      return _SystemMessage(text: message.systemText ?? '');
    }

    final bubbleColor = isMe
        ? AppTheme.primary
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = isMe ? Colors.white : Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
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
          child: Padding(
            padding: EdgeInsets.only(
              left: isMe ? 64 : 8,
              right: isMe ? 8 : 64,
              top: showSenderInfo ? 8 : 2,
              bottom: 2,
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && showSenderInfo) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 44, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _colorForSender(message.senderId),
                      ),
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isMe) ...[
                      if (showSenderInfo)
                        _SenderAvatar(
                            url: message.senderAvatarUrl,
                            name: message.senderName)
                      else
                        const SizedBox(width: 36),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
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
                                      color: Colors.black.withValues(alpha: 
                                          isDark ? 0.2 : 0.06),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 10, 6),
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
                                    if (message.forwardedFromGroupId != null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.reply_all_rounded,
                                                size: 14,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black38),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Forwarded',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: isMe
                                                    ? Colors.white70
                                                    : Colors.black38,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (message.mediaUrls.isNotEmpty &&
                                        message.messageType !=
                                            GroupMessageType.audio)
                                      _MediaContent(
                                          urls: message.mediaUrls,
                                          type: message.messageType,
                                          isMe: isMe),
                                    if (message.messageType ==
                                            GroupMessageType.audio &&
                                        message.mediaUrls.isNotEmpty)
                                      VoiceMessagePlayer(
                                        audioUrl: message.mediaUrls.first,
                                        durationSeconds:
                                            message.audioDuration ?? 0,
                                        isMe: isMe,
                                        isDark: isDark,
                                        onPlay: () =>
                                            onPlayAudio?.call(message),
                                      ),
                                    if (message.text.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: _MentionRichText(
                                          text: message.text,
                                          baseColor: textColor,
                                          isMe: isMe,
                                          members: members,
                                        ),
                                      ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.end,
                                      children: [
                                        if (message.isEdited)
                                          Text(
                                            'edited · ',
                                            style: TextStyle(
                                              fontSize: 10,
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
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white60
                                                : Colors.black38,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          _StatusIcon(
                                            seenCount: message.seenBy.length,
                                            memberCount: 2,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (message.reactions.isNotEmpty)
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showReactionsDetails(BuildContext context) {
    if (message.reactions.isEmpty) return;
    HapticFeedback.lightImpact();
    final usersData = message.reactions.keys.map((uid) {
      if (uid == currentUserId) {
         return ReactionUserData(id: uid, name: 'You');
      } else {
         final member = members?.where((m) => m.userId == uid).firstOrNull;
         return ReactionUserData(id: uid, name: member?.name ?? 'User', avatarUrl: member?.avatarUrl);
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
    final canDeleteForAll = message.canDeleteForEveryone(currentUserId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextMenu(
        message: message,
        isMe: isMe,
        isAdmin: isAdmin,
        canDeleteForAll: canDeleteForAll,
        currentUserReaction: message.reactions[currentUserId],
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
        onDeleteForAll: canDeleteForAll || isAdmin
            ? () {
                Navigator.pop(context);
                onDelete?.call(message, true);
              }
            : null,
        onInfo: isMe
            ? () {
                Navigator.pop(context);
                onInfo?.call(message);
              }
            : null,
        onReact: (emoji) {
          Navigator.pop(context);
          onReact?.call(message, emoji);
        },
        onPin: isAdmin
            ? () {
                Navigator.pop(context);
                onPin?.call(message);
              }
            : null,
        onCopy: () {
          Navigator.pop(context);
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

  static Color _colorForSender(String uid) {
    const colors = [
      Color(0xFF2563EB),
      Color(0xFF7C3AED),
      Color(0xFFDB2777),
      Color(0xFF059669),
      Color(0xFFD97706),
      Color(0xFF0891B2),
      Color(0xFFDC2626),
    ];
    int hash = 0;
    for (final ch in uid.codeUnits) {
      hash = (hash * 31 + ch) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SenderAvatar extends StatelessWidget {
  final String? url;
  final String name;
  const _SenderAvatar({this.url, required this.name});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 16,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary),
      ),
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
  final GroupMessageType type;
  final bool isMe;
  const _MediaContent({required this.urls, required this.type, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (type == GroupMessageType.image && urls.isNotEmpty) {
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
                memCacheWidth: 480,
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
          type == GroupMessageType.audio
              ? Icons.audiotrack_rounded
              : Icons.attach_file_rounded,
          size: 20,
          color: Colors.white70,
        ),
        const SizedBox(width: 6),
        Text(
          type == GroupMessageType.audio ? 'Voice message' : 'Attachment',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
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

class _StatusIcon extends StatelessWidget {
  final int seenCount;
  final int memberCount;
  const _StatusIcon({required this.seenCount, required this.memberCount});

  @override
  Widget build(BuildContext context) {
    // seenCount > 1 means at least one other person read it
    if (seenCount > 1) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.blue);
    }
    return const Icon(Icons.done_rounded, size: 14, color: Colors.white60);
  }
}

class _DeletedBubble extends StatelessWidget {
  final bool isMe;
  const _DeletedBubble({required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 64 : 8,
        right: isMe ? 8 : 64,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                'This message was deleted',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  final String text;
  const _SystemMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenu extends StatelessWidget {
  final GroupMessageEntity message;
  final bool isMe;
  final bool isAdmin;
  final bool canDeleteForAll;
  final String? currentUserReaction;
  final VoidCallback onReply;
  final VoidCallback? onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback? onDeleteForAll;
  final VoidCallback? onInfo;
  final void Function(String emoji) onReact;
  final VoidCallback? onPin;
  final VoidCallback onCopy;

  const _ContextMenu({
    required this.message,
    required this.isMe,
    required this.isAdmin,
    required this.canDeleteForAll,
    required this.currentUserReaction,
    required this.onReply,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForAll,
    required this.onInfo,
    required this.onReact,
    required this.onPin,
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

              // ── Emoji Quick Reactions ──────────────────────────────
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
                    if (onPin != null) ...[
                      _PremiumMenuItem(
                        icon: Icons.push_pin_rounded,
                        label: 'Pin Message',
                        iconBg: const Color(0xFF06B6D4),
                        onTap: onPin!,
                      ),
                      Divider(height: 1, color: divColor),
                    ],
                    if (onInfo != null) ...[
                      _PremiumMenuItem(
                        icon: Icons.info_outline_rounded,
                        label: 'Message Info',
                        iconBg: const Color(0xFF64748B),
                        onTap: onInfo!,
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




// ── Mention Rich Text ─────────────────────────────────────────────────────────

class _MentionRichText extends StatelessWidget {
  final String text;
  final Color baseColor;
  final bool isMe;
  final List<GroupMemberEntity>? members;

  const _MentionRichText({
    required this.text,
    required this.baseColor,
    required this.isMe,
    this.members,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    int lastEnd = 0;

    // Build dynamic regex from member names
    final sortedNames = members?.map((m) => m.name).toList() ?? [];
    sortedNames.sort((a, b) => b.length.compareTo(a.length));
    final escapedNames = sortedNames.map((name) => RegExp.escape(name)).join('|');
    final regexStr = escapedNames.isNotEmpty ? '@($escapedNames)' : r'@(\S+)';
    final mentionRegex = RegExp(regexStr, caseSensitive: false);

    for (final match in mentionRegex.allMatches(text)) {
      // Text before the @mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: baseColor, fontSize: 14, height: 1.3),
        ));
      }
      // The @mention itself
      final mentionText = match.group(0)!;
      spans.add(TextSpan(
        text: mentionText,
        style: TextStyle(
          color: isMe ? Colors.white : AppTheme.primary,
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ));
      lastEnd = match.end;
    }

    // Remaining text after last mention
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: baseColor, fontSize: 14, height: 1.3),
      ));
    }

    if (spans.isEmpty) {
      return Text(text,
          style: TextStyle(color: baseColor, fontSize: 14, height: 1.3));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

