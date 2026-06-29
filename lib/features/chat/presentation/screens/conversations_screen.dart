import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/config/i18n.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:project_test2/features/chat/domain/entities/conversation_entity.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_bloc.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_event.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_state.dart';
import 'package:project_test2/features/chat/presentation/screens/direct_message_screen.dart';
import 'package:project_test2/features/chat/presentation/widgets/mute_bottom_sheet.dart';
import 'package:project_test2/features/chat/presentation/screens/archived_conversations_screen.dart';

class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().currentUser?.uid ?? '';
    return BlocProvider(
      create: (_) => ConversationsBloc(repository: ChatRepositoryImpl())
        ..add(ConversationsStarted(myId)),
      child: const _ConversationsView(),
    );
  }
}

// ── Inner stateful view ───────────────────────────────────────────────────────

class _ConversationsView extends StatefulWidget {
  const _ConversationsView();

  @override
  State<_ConversationsView> createState() => _ConversationsViewState();
}

class _ConversationsViewState extends State<_ConversationsView>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  bool get wantKeepAlive => true;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _isSearching = false;
  List<UserModel> _searchResults = [];
  bool _searchLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() {
        _isSearching = true;
        _searchLoading = true;
      });
      final results = await _firestoreService.searchUsers(val.trim());
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    });
  }

  Future<void> _openChat(
    BuildContext context,
    String myId,
    String myName,
    String? myAvatar,
    UserModel other,
  ) async {
    final repo = ChatRepositoryImpl();
    final conv = await repo.getOrCreateConversation(
      myId: myId,
      myName: myName,
      myAvatar: myAvatar,
      otherId: other.uid,
      otherName: other.name,
      otherAvatar: other.avatarUrl,
    );

    if (!context.mounted) return;

    final conversationsBloc = context.read<ConversationsBloc>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: conversationsBloc,
          child: DirectMessageScreen(
            conversationId: conv.id,
            otherUserId: other.uid,
            otherUserName: other.name,
            otherUserAvatar: other.avatarUrl,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final me = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (context, state) {
        final isSelectionMode = state is ConversationsLoaded && state.isSelectionMode;
        final selectedIds = state is ConversationsLoaded ? state.selectedChatIds : const <String>{};

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF111620) : const Color(0xFFF5F7FF),
          body: NestedScrollView(
            key: const PageStorageKey('conversations_nested_scroll'),
            headerSliverBuilder: (ctx, _) => [
              _buildSliverAppBar(context, theme, isDark, me, isSelectionMode, selectedIds, state),
            ],
            body: _isSearching
                ? _buildSearchResults(context, me, isDark, theme)
                : _buildConversationList(me, isDark, theme, isSelectionMode, selectedIds),
          ),
        );
      },
    );
  }

  // ── Sliver header ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    UserModel me,
    bool isSelectionMode,
    Set<String> selectedIds,
    ConversationsState state,
  ) {
    if (isSelectionMode) {
      final loadedConvs = state is ConversationsLoaded ? state.conversations : <ConversationEntity>[];
      final selectedConvs = loadedConvs.where((c) => selectedIds.contains(c.id)).toList();
      final allPinned = selectedConvs.isNotEmpty && selectedConvs.every((c) => c.isPinned(me.uid));
      final allMuted = selectedConvs.isNotEmpty && selectedConvs.every((c) => c.isMuted(me.uid));
      final allArchived = selectedConvs.isNotEmpty && selectedConvs.every((c) => c.isArchived(me.uid));

      return SliverAppBar(
        pinned: true,
        expandedHeight: kToolbarHeight,
        backgroundColor:
            isDark ? const Color(0xFF1A2540) : const Color(0xFFEEF2FF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: isDark ? Colors.white : const Color(0xFF1A2540),
          ),
          onPressed: () {
            context.read<ConversationsBloc>().add(const ConversationsClearSelection());
          },
        ),
        title: Text(
          '${selectedIds.length} Selected',
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
            onPressed: () {
              context.read<ConversationsBloc>().add(
                    ConversationsPinSelected(me.uid, pin: !allPinned),
                  );
            },
            tooltip: allPinned ? 'Unpin' : 'Pin',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: isDark ? Colors.white : const Color(0xFF1A2540),
            ),
            onPressed: () {
              _showBatchDeleteConfirmation(context, selectedIds.toList(), me.uid);
            },
            tooltip: 'Delete',
          ),
          IconButton(
            icon: Icon(
              allMuted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
              color: isDark ? Colors.white : const Color(0xFF1A2540),
            ),
            onPressed: () {
              MuteBottomSheet.show(
                context,
                isCurrentlyMuted: allMuted,
                onMuteSelected: (muteUntil) {
                  final bloc = context.read<ConversationsBloc>();
                  for (final id in selectedIds) {
                    bloc.add(ConversationsMuteConversation(
                      conversationId: id,
                      userId: me.uid,
                      muteUntil: muteUntil,
                    ));
                  }
                  bloc.add(const ConversationsClearSelection());
                },
              );
            },
            tooltip: allMuted ? 'Unmute' : 'Mute',
          ),
          IconButton(
            icon: Icon(
              allArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
              color: isDark ? Colors.white : const Color(0xFF1A2540),
            ),
            onPressed: () {
              context.read<ConversationsBloc>().add(
                    ConversationsArchiveSelected(me.uid, archive: !allArchived),
                  );
            },
            tooltip: allArchived ? 'Unarchive' : 'Archive',
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDark ? Colors.white : const Color(0xFF1A2540),
            ),
            onPressed: () {
              // Placeholder for more options if needed
            },
            tooltip: 'More Options',
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2540), const Color(0xFF0D1117)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      );
    }

    return SliverAppBar(
      pinned: true,
      expandedHeight: 140,
      backgroundColor:
          isDark ? const Color(0xFF1A2540) : const Color(0xFFEEF2FF),
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2540), const Color(0xFF0D1117)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 74),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_rounded,
                          color: isDark ? Colors.white : const Color(0xFF1A2540),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Messages',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF1A2540),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        // Circular Edit Button
                        GestureDetector(
                          onTap: () => _searchFocus.requestFocus(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B6BD4),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: _buildSearchBar(isDark),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: Size.zero,
        child: Container(),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : const Color(0xFFE8ECF5),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF1A2540),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Search or start new chat...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
                filled: false,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_isSearching)
            GestureDetector(
              onTap: () {
                _searchCtrl.clear();
                setState(() {
                  _isSearching = false;
                  _searchResults = [];
                });
                _searchFocus.unfocus();
              },
              child: Icon(
                Icons.close_rounded,
                color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0),
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  // ── Conversation list ──────────────────────────────────────────────────────

  Widget _buildConversationList(
      UserModel me, bool isDark, ThemeData theme, bool isSelectionMode, Set<String> selectedIds) {
    return BlocBuilder<ConversationsBloc, ConversationsState>(
      builder: (_, state) {
        if (state is ConversationsLoading) {
          return _buildShimmerLoading(isDark);
        }

        if (state is ConversationsError) {
          return Center(
            child: Text(state.message,
                style: TextStyle(
                    color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0))),
          );
        }

        if (state is ConversationsLoaded) {
          return StreamBuilder<List<ConversationEntity>>(
            stream: ChatRepositoryImpl().watchArchivedConversations(me.uid),
            builder: (context, archivedSnapshot) {
              final archivedCount = archivedSnapshot.data?.length ?? 0;
              final hasArchived = archivedCount > 0;

              if (state.conversations.isEmpty && !hasArchived) {
                return _buildEmptyState(isDark, theme);
              }

              final sortedConversations = [...state.conversations]..sort((a, b) {
                final aPinned = a.isPinned(me.uid);
                final bPinned = b.isPinned(me.uid);
                if (aPinned && !bPinned) return -1;
                if (!aPinned && bPinned) return 1;
                return b.lastMessageAt.compareTo(a.lastMessageAt);
              });

              final showArchivedHeader = hasArchived;
              final itemCount = sortedConversations.length + (showArchivedHeader ? 1 : 0);

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: itemCount,
                itemBuilder: (ctx, i) {
                  if (showArchivedHeader && i == 0) {
                    return _buildArchivedHeader(ctx, me.uid, archivedCount, isDark, theme);
                  }
                  final convIndex = showArchivedHeader ? i - 1 : i;
                  final conv = sortedConversations[convIndex];
                  final isSelected = selectedIds.contains(conv.id);
                  return _ConversationTile(
                    conv: conv,
                    myId: me.uid,
                    isDark: isDark,
                    theme: theme,
                    isSelected: isSelected,
                    isSelectionMode: isSelectionMode,
                    onTap: () async {
                      if (isSelectionMode) {
                        context.read<ConversationsBloc>().add(
                              ConversationsToggleSelect(conv.id),
                            );
                      } else {
                        final otherId = conv.otherUserId(me.uid);
                        final conversationsBloc = context.read<ConversationsBloc>();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: conversationsBloc,
                              child: DirectMessageScreen(
                                conversationId: conv.id,
                                otherUserId: otherId,
                                otherUserName: conv.otherUserName(me.uid),
                                otherUserAvatar: conv.otherUserAvatar(me.uid),
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    onLongPress: () {
                      context.read<ConversationsBloc>().add(
                            ConversationsToggleSelect(conv.id),
                          );
                    },
                  );
                },
              );
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildArchivedHeader(
    BuildContext context,
    String myId,
    int count,
    bool isDark,
    ThemeData theme,
  ) {
    final titleColor = isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF1A2540);
    final countColor = isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF8A94B0);
    final iconColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1A2540);

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ArchivedConversationsScreen(myId: myId, isDark: isDark),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFE8ECF5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.archive_outlined,
              color: iconColor,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(
              'Archived',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            const Spacer(),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: countColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shimmer loading placeholder ────────────────────────────────────────────

  Widget _buildShimmerLoading(bool isDark) {
    final base = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final highlight =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEF1F8);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8ECF5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _shimmerBox(48, 48, highlight, shape: BoxShape.circle),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(16, 120, highlight),
                  const SizedBox(height: 8),
                  _shimmerBox(12, 200, highlight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox(double h, double w, Color color,
      {BoxShape shape = BoxShape.rectangle}) {
    return Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.rectangle ? BorderRadius.circular(6) : null,
      ),
    );
  }

  // ── Search results ─────────────────────────────────────────────────────────

  Widget _buildSearchResults(
      BuildContext context, UserModel me, bool isDark, ThemeData theme) {
    if (_searchLoading) return const Center(child: CircularProgressIndicator());

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded,
                size: 64,
                color: AppTheme.textTertiary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr(en: 'No users found', ar: 'لا يوجد مستخدمون'),
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) {
        final user = _searchResults[i];
        if (user.uid == me.uid) return const SizedBox.shrink();
        return _SearchUserTile(
          user: user,
          isDark: isDark,
          onTap: () => _openChat(
            context,
            me.uid,
            me.name,
            me.avatarUrl,
            user,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: AppTheme.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              'No conversations yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Search for someone to start chatting',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _searchFocus.requestFocus(),
              icon: const Icon(Icons.search_rounded),
              label: const Text('Find people'),
            ),
          ],
        ),
      ),
    );
  }



  void _showBatchDeleteConfirmation(
    BuildContext context,
    List<String> selectedIds,
    String userId,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: Text(
                  selectedIds.length > 1 ? 'Delete Chats' : 'Delete Chat',
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: const Text(
                  'Permanently delete selected conversations',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.read<ConversationsBloc>().add(
                        ConversationsDeleteSelected(userId),
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Conversation Tile ──────────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationEntity conv;
  final String myId;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final bool isSelectionMode;

  const _ConversationTile({
    required this.conv,
    required this.myId,
    required this.isDark,
    required this.theme,
    required this.onTap,
    this.onLongPress,
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

// ── Search User Tile ───────────────────────────────────────────────────────────

class _SearchUserTile extends StatelessWidget {
  final UserModel user;
  final bool isDark;
  final VoidCallback onTap;

  const _SearchUserTile({
    required this.user,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (user.avatarUrl ?? '').trim();

    final cardBgColor = isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white;
    final cardBorderColor = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8ECF5);
    final titleColor = isDark ? Colors.white : const Color(0xFF1A2540);
    final previewColor = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF8A94B0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorderColor, width: 1.0),
        ),
        child: Row(
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
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A2540),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      color: titleColor,
                    ),
                  ),
                  if ((user.bio ?? '').isNotEmpty)
                    Text(
                      user.bio!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: previewColor,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Message',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
