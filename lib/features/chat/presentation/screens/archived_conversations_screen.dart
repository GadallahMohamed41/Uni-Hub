import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
import 'package:project_test2/features/chat/presentation/screens/direct_message_screen.dart';
import 'package:project_test2/features/chat/presentation/widgets/mute_bottom_sheet.dart';
=======
import '../../../../core/theme.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/conversation_entity.dart';
import 'direct_message_screen.dart';
import '../widgets/mute_bottom_sheet.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class ArchivedConversationsScreen extends StatefulWidget {
  final String myId;
  final bool isDark;

  const ArchivedConversationsScreen({
    super.key,
    required this.myId,
    required this.isDark,
  });

  @override
  State<ArchivedConversationsScreen> createState() => _ArchivedConversationsScreenState();
}

class _ArchivedConversationsScreenState extends State<ArchivedConversationsScreen> {
  final Set<String> _selectedIds = {};
  final ChatRepositoryImpl _repository = ChatRepositoryImpl();

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _unarchiveSelected() async {
    final ids = _selectedIds.toList();
    _clearSelection();
    try {
      await _repository.archiveConversationsBatch(ids, widget.myId, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversations unarchived')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unarchive: $e')),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversations'),
        content: Text('Are you sure you want to delete these ${ids.length} conversations? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _clearSelection();
    try {
      await _repository.deleteConversationsBatch(ids, widget.myId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversations deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  Future<void> _pinSelected(bool pin) async {
    final ids = _selectedIds.toList();
    _clearSelection();
    try {
      await _repository.pinConversationsBatch(ids, widget.myId, pin);
    } catch (_) {}
  }

  void _muteSelected(bool allMuted) {
    MuteBottomSheet.show(
      context,
      isCurrentlyMuted: allMuted,
      onMuteSelected: (muteUntil) async {
        final ids = _selectedIds.toList();
        _clearSelection();
        for (final id in ids) {
          try {
            await _repository.muteConversation(id, widget.myId, muteUntil);
          } catch (_) {}
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDark;

    return StreamBuilder<List<ConversationEntity>>(
      stream: _repository.watchArchivedConversations(widget.myId),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];

        // Filter selected IDs to make sure they still exist in the current list
        final validSelected = _selectedIds.where((id) => conversations.any((c) => c.id == id)).toList();
        final allPinned = validSelected.isNotEmpty && validSelected.every((id) {
          final c = conversations.firstWhere((conv) => conv.id == id);
          return c.isPinned(widget.myId);
        });
        final allMuted = validSelected.isNotEmpty && validSelected.every((id) {
          final c = conversations.firstWhere((conv) => conv.id == id);
          return c.isMuted(widget.myId);
        });

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF111620) : const Color(0xFFF5F7FF),
          appBar: _isSelectionMode
              ? AppBar(
                  backgroundColor: isDark ? const Color(0xFF1A2540) : const Color(0xFFEEF2FF),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1A2540),
                    ),
                    onPressed: _clearSelection,
                  ),
                  title: Text(
                    '${_selectedIds.length} Selected',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A2540),
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        allPinned ? Icons.push_pin : Icons.push_pin_outlined,
                        color: isDark ? Colors.white : const Color(0xFF1A2540),
                      ),
                      onPressed: () => _pinSelected(!allPinned),
                      tooltip: allPinned ? 'Unpin' : 'Pin',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: isDark ? Colors.white : const Color(0xFF1A2540),
                      ),
                      onPressed: _deleteSelected,
                      tooltip: 'Delete',
                    ),
                    IconButton(
                      icon: Icon(
                        allMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                        color: isDark ? Colors.white : const Color(0xFF1A2540),
                      ),
                      onPressed: () => _muteSelected(allMuted),
                      tooltip: allMuted ? 'Unmute' : 'Mute',
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.unarchive_outlined,
                        color: isDark ? Colors.white : const Color(0xFF1A2540),
                      ),
                      onPressed: _unarchiveSelected,
                      tooltip: 'Unarchive',
                    ),
                    const SizedBox(width: 8),
                  ],
                )
              : AppBar(
                  backgroundColor: isDark ? const Color(0xFF111620) : const Color(0xFFF5F7FF),
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1A2540),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    'Archived Chats',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1A2540),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : conversations.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: conversations.length,
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isSelected = _selectedIds.contains(conv.id);
                        return _ArchivedConversationTile(
                          conv: conv,
                          myId: widget.myId,
                          isDark: isDark,
                          theme: theme,
                          isSelected: isSelected,
                          isSelectionMode: _isSelectionMode,
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(conv.id);
                            } else {
                              final otherId = conv.otherUserId(widget.myId);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DirectMessageScreen(
                                    conversationId: conv.id,
                                    otherUserId: otherId,
                                    otherUserName: conv.otherUserName(widget.myId),
                                    otherUserAvatar: conv.otherUserAvatar(widget.myId),
                                  ),
                                ),
                              );
                            }
                          },
                          onLongPress: () {
                            _toggleSelection(conv.id);
                          },
                        );
                      },
                    ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 64,
            color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No archived chats',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchivedConversationTile extends StatelessWidget {
  final ConversationEntity conv;
  final String myId;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const _ArchivedConversationTile({
    required this.conv,
    required this.myId,
    required this.isDark,
    required this.theme,
    required this.onTap,
    required this.onLongPress,
    required this.isSelected,
    required this.isSelectionMode,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('d MMM').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (conv.otherUserAvatar(myId) ?? '').trim();
    final name = conv.otherUserName(myId);
    final unread = conv.myUnread(myId);
    final isMyMsg = conv.lastMessageSenderId == myId;
    final isDeleted = conv.lastMessage == '🚫 This message was deleted' || conv.lastMessage == 'This message was deleted';
    final lastMsg = conv.lastMessage.isEmpty
        ? 'Start the conversation...'
        : isDeleted
            ? conv.lastMessage
            : isMyMsg
                ? 'You: ${conv.lastMessage}'
                : conv.lastMessage;

    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8ECF5);
    final dotBorderColor = isDark ? const Color(0xFF161A26) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A2540);
    final previewColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0);
    final dateColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0);

    final Color selectedBgColor = isDark
        ? const Color(0xFF3B6BD4).withValues(alpha: 0.15)
        : const Color(0xFF3B6BD4).withValues(alpha: 0.08);
    final Color selectedBorderColor = const Color(0xFF3B6BD4);

    final bg = isSelected ? selectedBgColor : cardBgColor;
    final border = isSelected ? selectedBorderColor : cardBorderColor;
    final borderWidth = isSelected ? 1.2 : 1.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2FF),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF1A2540),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dotBorderColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 15,
                                  color: titleColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (conv.isMuted(myId))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(Icons.volume_off_rounded,
                                    size: 14, color: previewColor),
                              ),
                            if (conv.isPinned(myId))
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Icon(Icons.push_pin_rounded,
                                    size: 14, color: AppTheme.primary),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(conv.lastMessageAt),
                        style: TextStyle(
                          color: dateColor,
                          fontSize: 11,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: previewColor,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread > 99 ? '99+' : unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
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
    );
  }
}
