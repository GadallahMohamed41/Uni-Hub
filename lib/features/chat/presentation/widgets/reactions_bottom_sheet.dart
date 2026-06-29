import 'package:flutter/material.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReactionUserData {
  final String id;
  final String name;
  final String? avatarUrl;

  const ReactionUserData({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}

class ReactionsBottomSheet extends StatefulWidget {
  final Map<String, String> reactions;
  final String currentUserId;
  // A simple list to look up user data for rendering the reactions sheet
  final List<ReactionUserData> usersData;
  // Tapping a user row calls this to navigate to their profile
  final void Function(String userId) onUserTapped;
  // Removing own reaction
  final void Function(String emoji) onToggleReaction;

  const ReactionsBottomSheet({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.usersData,
    required this.onUserTapped,
    required this.onToggleReaction,
  });

  @override
  State<ReactionsBottomSheet> createState() => _ReactionsBottomSheetState();
}

class _ReactionsBottomSheetState extends State<ReactionsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _uniqueEmojis;
  late Map<String, List<String>> _groupedReactions; // emoji -> list of userIds

  @override
  void initState() {
    super.initState();
    _processReactions();
    _tabController = TabController(length: _uniqueEmojis.length + 1, vsync: this);
  }

  void _processReactions() {
    _groupedReactions = {};
    for (final entry in widget.reactions.entries) {
      final userId = entry.key;
      final emoji = entry.value;
      if (!_groupedReactions.containsKey(emoji)) {
        _groupedReactions[emoji] = [];
      }
      _groupedReactions[emoji]!.add(userId);
    }
    _uniqueEmojis = _groupedReactions.keys.toList();
    // Sort emojis by count descending
    _uniqueEmojis.sort((a, b) =>
        _groupedReactions[b]!.length.compareTo(_groupedReactions[a]!.length));
  }

  @override
  void didUpdateWidget(ReactionsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactions != oldWidget.reactions) {
      _processReactions();
      if (_tabController.length != _uniqueEmojis.length + 1) {
        final currentIdx = _tabController.index;
        _tabController.dispose();
        _tabController =
            TabController(length: _uniqueEmojis.length + 1, vsync: this);
        if (currentIdx < _tabController.length) {
          _tabController.index = currentIdx;
        }
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  ReactionUserData _getUserData(String userId) {
    if (userId == widget.currentUserId) {
      return ReactionUserData(id: userId, name: 'You');
    }
    return widget.usersData.firstWhere(
      (u) => u.id == userId,
      orElse: () => ReactionUserData(id: userId, name: 'User'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    if (widget.reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
        minHeight: 200,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Tabs
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.primary,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: AppTheme.primary,
            dividerColor: Colors.transparent,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'All ${widget.reactions.length}'),
              ..._uniqueEmojis.map((emoji) {
                final count = _groupedReactions[emoji]!.length;
                return Tab(text: '$emoji $count');
              }),
            ],
          ),
          Divider(
              height: 1,
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // All tab
                _buildUserList(widget.reactions.keys.toList(), isDark),
                // Per emoji tabs
                ..._uniqueEmojis.map((emoji) {
                  return _buildUserList(_groupedReactions[emoji]!, isDark,
                      filterEmoji: emoji);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<String> userIds, bool isDark,
      {String? filterEmoji}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: userIds.length,
      itemBuilder: (context, index) {
        final userId = userIds[index];
        final userData = _getUserData(userId);
        final emoji = widget.reactions[userId]!;
        final isMe = userId == widget.currentUserId;

        return InkWell(
          onTap: () {
            if (isMe) {
              widget.onToggleReaction(emoji);
            } else {
              widget.onUserTapped(userId);
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      backgroundImage:
                          (userData.avatarUrl != null && userData.avatarUrl!.isNotEmpty)
                              ? CachedNetworkImageProvider(userData.avatarUrl!)
                              : null,
                      child: (userData.avatarUrl == null ||
                              userData.avatarUrl!.isEmpty)
                          ? Text(
                              userData.name.isNotEmpty
                                  ? userData.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    userData.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                if (isMe)
                  Text(
                    'Tap to remove',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
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
