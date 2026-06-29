import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/community/data/repositories/group_repository_impl.dart';
import 'package:project_test2/features/community/domain/entities/group_message_entity.dart';
import 'package:project_test2/features/community/presentation/bloc/group_chat/group_chat_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/group_chat/group_chat_event.dart';
import 'package:project_test2/features/community/presentation/bloc/group_chat/group_chat_state.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/groups_list/groups_list_event.dart';
import 'package:project_test2/features/chat/presentation/widgets/mute_bottom_sheet.dart';
import 'package:project_test2/features/community/presentation/widgets/group_avatar.dart';
import 'package:project_test2/features/community/presentation/widgets/group_message_bubble.dart';
import 'package:project_test2/features/community/presentation/widgets/group_typing_indicator.dart';
import 'package:project_test2/features/community/presentation/widgets/pinned_message_banner.dart';
import 'package:project_test2/features/community/presentation/screens/group_info_screen.dart';
import 'package:project_test2/features/community/presentation/screens/group_search_screen.dart';
import 'package:project_test2/features/community/presentation/screens/message_info_screen.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/features/chat/presentation/widgets/voice_recorder_bar.dart';
import 'package:project_test2/features/community/domain/entities/group_member_entity.dart';


class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;

  // Track group IDs that the user is actively/voluntarily leaving
  static final Set<String> leavingGroupIds = {};

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatarUrl,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  late final GroupChatBloc _bloc;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _exitDialogShown = false;
  bool _accessDeniedHandled = false;

  @override
  void initState() {
    super.initState();
    _bloc = GroupChatBloc(
      repository: GroupRepositoryImpl(),
      groupId: widget.groupId,
      currentUserId: widget.currentUserId,
    );
    _bloc.add(GroupChatStarted(
      groupId: widget.groupId,
      currentUserId: widget.currentUserId,
    ));

    _scrollCtrl.addListener(_onScroll);
    _textCtrl.addListener(_onTextChanged);
  }

  void _onScroll() {
    // Load more when reaching top
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _bloc.add(const GroupChatLoadMore());
    }
  }

  void _onTextChanged() {
    final typing = _textCtrl.text.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      _bloc.add(
          GroupChatTypingChanged(userId: widget.currentUserId, isTyping: typing));
    }
  }

  @override
  void dispose() {
    GroupChatScreen.leavingGroupIds.remove(widget.groupId);
    _bloc.close();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage({List<String> mentionedUserIds = const []}) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final state = _bloc.state;
    final reply =
        state is GroupChatLoaded ? state.replyingTo : null;

    _bloc.add(GroupChatSendMessage(
      senderId: widget.currentUserId,
      senderName: widget.currentUserName,
      senderAvatarUrl: widget.currentUserAvatarUrl,
      text: text,
      replyToMessageId: reply?.id,
      replyToText: reply?.text,
      replyToSenderId: reply?.senderId,
      replyToSenderName: reply?.senderName,
      mentionedUserIds: mentionedUserIds,
    ));
    _textCtrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocConsumer<GroupChatBloc, GroupChatState>(
        listener: (context, state) {
          if (state is GroupChatAccessDenied) {
            if (_accessDeniedHandled) return;
            _accessDeniedHandled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('You are not a member of this group.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).maybePop();
            });
          }
          if (state is GroupChatKicked) {
            if (GroupChatScreen.leavingGroupIds.contains(widget.groupId)) {
              return;
            }
            if (_exitDialogShown) return;
            _exitDialogShown = true;
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('تنبيه'),
                content: const Text('تمت إزالتك من الجروب'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ).then((_) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          }
          if (state is GroupChatDeleted) {
            if (GroupChatScreen.leavingGroupIds.contains(widget.groupId)) {
              return;
            }
            if (_exitDialogShown) return;
            _exitDialogShown = true;
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text('تنبيه'),
                content: const Text('تم حذف الجروب'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حسناً'),
                  ),
                ],
              ),
            ).then((_) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            });
          }
          if (state is GroupChatLoaded && state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(state.error!),
                  backgroundColor: AppTheme.error),
            );
            _bloc.add(const GroupChatErrorCleared());
          }
          // Mark messages as seen when new ones arrive
          if (state is GroupChatLoaded && state.messages.isNotEmpty) {
            final unseenIds = state.messages
                .where((m) =>
                    m.senderId != widget.currentUserId &&
                    !m.seenBy.containsKey(widget.currentUserId))
                .map((m) => m.id)
                .toList();
            if (unseenIds.isNotEmpty) {
              _bloc.add(GroupChatMarkSeen(
                  userId: widget.currentUserId, messageIds: unseenIds));
            }
          }
        },
        builder: (context, state) {
          if (state is GroupChatLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is GroupChatAccessDenied) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is! GroupChatLoaded) {
            return const Scaffold();
          }

          final group = state.group;
          final messages = state.messages;
          final isAdmin = group.isAdmin(widget.currentUserId);
          final isActiveMember = group.isActiveMember(widget.currentUserId);
          final canSend = group.canSend(widget.currentUserId);
          final typingNames =
              state.typingNames(widget.currentUserId);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              backgroundColor: AppTheme.primary,
              leading: BackButton(color: Colors.white),
              title: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupInfoScreen(
                      groupId: group.id,
                      currentUserId: widget.currentUserId,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    GroupAvatar(
                      imageUrl: group.imageUrl,
                      groupName: group.name,
                      radius: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    group.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (state.memberById(widget.currentUserId)?.isMuted ?? false)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(Icons.volume_off_rounded,
                                        size: 14, color: Colors.white70),
                                  ),
                              ],
                            ),
                          Text(
                            '${group.memberIds.length} members',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded, color: Colors.white),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupSearchScreen(
                        group: group,
                        currentUserId: widget.currentUserId,
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'info') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupInfoScreen(
                            groupId: group.id,
                            currentUserId: widget.currentUserId,
                          ),
                        ),
                      );
                    } else if (value == 'mute') {
                      MuteBottomSheet.show(
                        context,
                        isCurrentlyMuted: state.memberById(widget.currentUserId)?.isMuted ?? false,
                        onMuteSelected: (muteUntil) {
                          final targetMuteUntil = muteUntil ?? DateTime.now().subtract(const Duration(days: 1));
                          context.read<GroupsListBloc>().add(
                                GroupsListMuteGroup(
                                  groupId: group.id,
                                  userId: widget.currentUserId,
                                  muteUntil: targetMuteUntil,
                                ),
                              );
                        },
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(
                            (state.memberById(widget.currentUserId)?.isMuted ?? false)
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (state.memberById(widget.currentUserId)?.isMuted ?? false)
                                ? 'إلغاء كتم الإشعارات'
                                : 'كتم الإشعارات',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'info',
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'معلومات المجموعة',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Stack(
              children: [
                // Chat wallpaper background
                Positioned.fill(
                  child: isDark
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF0A0F1E),
                                Color(0xFF141929),
                                Color(0xFF0A0F1E),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFDCF8C6),
                                Color(0xFFF0FFF4),
                                Color(0xFFE8F4FD),
                              ],
                            ),
                          ),
                        ),
                ),
                Positioned.fill(
                  child: Column(
                    children: [
                      // Pinned message banner
                    if (group.pinnedMessageId != null) ...[
                      Builder(builder: (_) {
                        final pinned = messages.where(
                            (m) => m.id == group.pinnedMessageId).firstOrNull;
                        if (pinned == null) return const SizedBox.shrink();
                        return PinnedMessageBanner(
                          message: pinned,
                          canDismiss: isAdmin,
                          onTap: () => _scrollToMessage(pinned.id, messages),
                          onDismiss: () => _bloc.add(GroupChatUnpinMessage(
                              actorId: widget.currentUserId)),
                        );
                      }),
                    ],

                    // Message list
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyChat(groupName: group.name)
                          : ListView.builder(
                              controller: _scrollCtrl,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length +
                                  (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == messages.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Center(
                                        child: CircularProgressIndicator()),
                                  );
                                }
                                final idx = messages.length - 1 - i;
                                final msg = messages[idx];
                                final prev =
                                    idx > 0 ? messages[idx - 1] : null;
                                final next =
                                    idx < messages.length - 1
                                        ? messages[idx + 1]
                                        : null;

                                // Date separator
                                final showDate = prev == null ||
                                    !_sameDay(prev.createdAt, msg.createdAt);

                                return Column(
                                  children: [
                                    if (showDate)
                                      _DateSeparator(date: msg.createdAt),
                                    GroupMessageBubble(
                                      message: msg,
                                      isMe: msg.senderId ==
                                          widget.currentUserId,
                                      showSenderInfo: next == null ||
                                          next.senderId != msg.senderId ||
                                          msg.messageType ==
                                              GroupMessageType.system,
                                      currentUserId: widget.currentUserId,
                                      isAdmin: isAdmin,
                                      members: state.members,
                                      onReply: isActiveMember
                                          ? (m) => _bloc.add(GroupChatSetReply(m))
                                          : null,
                                      onEdit: isActiveMember
                                          ? (m) => _showEditDialog(context, m)
                                          : null,
                                      onDelete: isActiveMember
                                          ? (m, forAll) => forAll
                                              ? _bloc.add(
                                                  GroupChatDeleteMessageForEveryone(
                                                    messageId: m.id,
                                                    senderId: widget.currentUserId,
                                                  ))
                                              : _bloc.add(
                                                  GroupChatDeleteMessageForMe(
                                                    messageId: m.id,
                                                    userId: widget.currentUserId,
                                                  ))
                                          : null,
                                      onInfo: (m) => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => MessageInfoScreen(
                                            message: m,
                                            members: state.members,
                                          ),
                                        ),
                                      ),
                                      onReact: isActiveMember
                                          ? (m, emoji) {
                                              final myReaction =
                                                  m.reactions[widget.currentUserId];
                                              if (myReaction == emoji) {
                                                _bloc.add(GroupChatRemoveReaction(
                                                  messageId: m.id,
                                                  userId: widget.currentUserId,
                                                ));
                                              } else {
                                                _bloc.add(GroupChatReactToMessage(
                                                  messageId: m.id,
                                                  userId: widget.currentUserId,
                                                  emoji: emoji,
                                                ));
                                              }
                                            }
                                          : null,
                                      onPin: isActiveMember && isAdmin
                                          ? (m) => _bloc.add(GroupChatPinMessage(
                                                messageId: m.id,
                                                actorId: widget.currentUserId,
                                              ))
                                          : null,
                                      onPlayAudio: (m) => _bloc.add(
                                        GroupChatMarkListened(
                                          userId: widget.currentUserId,
                                          messageId: m.id,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),

                    // Typing indicator
                    if (typingNames.isNotEmpty && isActiveMember)
                      GroupTypingIndicator(typingNames: typingNames),

                    // Input bar / Banner
                    if (isActiveMember)
                      _InputBar(
                        controller: _textCtrl,
                        replyingTo: state.replyingTo,
                        canSend: canSend,
                        isSending: state.isSending,
                        onSend: _sendMessage,
                        onCancelReply: () =>
                            _bloc.add(const GroupChatSetReply(null)),
                        groupId: group.id,
                        currentUserId: widget.currentUserId,
                        currentUserName: widget.currentUserName,
                        currentUserAvatarUrl: widget.currentUserAvatarUrl,
                        bloc: _bloc,
                        members: state.members,
                      )
                    else
                      _buildLeftGroupBanner(context, isDark),
                  ],
                ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeftGroupBanner(BuildContext context, bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final textColor = isDark ? Colors.redAccent : Colors.red.shade700;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, color: textColor),
            const SizedBox(width: 8),
            Text(
              'You left this group',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToMessage(String id, List<GroupMessageEntity> messages) {
    final idx = messages.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final scrollIdx = messages.length - 1 - idx;
    _scrollCtrl.animateTo(
      scrollIdx * 80.0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _showEditDialog(BuildContext context, GroupMessageEntity msg) {
    final ctrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Message'),
        content: TextField(
          controller: ctrl,
          maxLines: null,
          decoration: const InputDecoration(hintText: 'New message...'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final newText = ctrl.text.trim();
              if (newText.isNotEmpty) {
                _bloc.add(GroupChatEditMessage(
                  messageId: msg.id,
                  newText: newText,
                  editorId: widget.currentUserId,
                ));
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final GroupMessageEntity? replyingTo;
  final bool canSend;
  final bool isSending;
  final void Function({List<String> mentionedUserIds}) onSend;
  final VoidCallback onCancelReply;
  final List<GroupMemberEntity> members;

  const _InputBar({
    required this.controller,
    required this.replyingTo,
    required this.canSend,
    required this.isSending,
    required this.onSend,
    required this.onCancelReply,
    required this.groupId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserAvatarUrl,
    required this.bloc,
    required this.members,
  });

  final String groupId;
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;
  final GroupChatBloc bloc;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> with WidgetsBindingObserver {
  // ── Functional state ──────────────────────────────────────────────────────
  bool _isRecordingVoice = false;
  bool _isVoiceLocked = false;
  bool _voiceHoldFinished = false;
  bool _isUploadingVoice = false;
  bool _isUploadingMedia = false;
  final _storage = StorageService();
  final _voiceRecorderKey = GlobalKey<VoiceRecorderBarState>();

  // ── Mention state ─────────────────────────────────────────────────────────
  bool _isMentioning = false;
  String _mentionQuery = '';
  int _mentionAtOffset = -1;
  final List<String> _mentionedUserIds = [];

  // ── Interaction state ─────────────────────────────────────────────────────
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addObserver(this);
  }

  void _onFocusChange() {
    if (!mounted) return;
    final focused = _focusNode.hasFocus;
    setState(() => _isFocused = focused);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isRecordingVoice && !_isVoiceLocked) {
        setState(() {
          _isVoiceLocked = true;
        });
      }
      _voiceRecorderKey.currentState?.handleInterruption();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  // ── Mention logic ─────────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    final sel = widget.controller.selection;
    if (!sel.isValid) return;
    final cursorPos = sel.baseOffset;
    if (cursorPos < 0) return;
    final before = text.substring(0, cursorPos);
    final atIdx = before.lastIndexOf('@');
    if (atIdx != -1) {
      final query = before.substring(atIdx + 1);
      if (!query.contains(' ') && query.length <= 30) {
        setState(() {
          _isMentioning = true;
          _mentionQuery = query;
          _mentionAtOffset = atIdx;
        });
        return;
      }
    }
    if (_isMentioning) setState(() => _isMentioning = false);
  }

  void _selectMention(GroupMemberEntity member) {
    final text = widget.controller.text;
    final before = text.substring(0, _mentionAtOffset);
    final afterCursor = text.substring(widget.controller.selection.baseOffset);
    final inserted = '@${member.name} ';
    final newText = '$before$inserted$afterCursor';
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: before.length + inserted.length),
    );
    if (!_mentionedUserIds.contains(member.userId)) {
      _mentionedUserIds.add(member.userId);
    }
    setState(() => _isMentioning = false);
  }

  List<GroupMemberEntity> get _filteredMembers {
    if (_mentionQuery.isEmpty) return widget.members;
    final q = _mentionQuery.toLowerCase();
    return widget.members.where((m) => m.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    setState(() => _isUploadingMedia = true);
    try {
      final url = await _storage.uploadGroupImage(File(file.path));
      if (url != null) {
        widget.bloc.add(GroupChatSendMessage(
          senderId: widget.currentUserId,
          senderName: widget.currentUserName,
          senderAvatarUrl: widget.currentUserAvatarUrl,
          text: '',
          messageType: GroupMessageType.image,
          mediaUrls: [url],
          replyToMessageId: widget.replyingTo?.id,
          replyToText: widget.replyingTo?.text,
          replyToSenderId: widget.replyingTo?.senderId,
          replyToSenderName: widget.replyingTo?.senderName,
        ));
        widget.onCancelReply();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingMedia = false);
    }
  }

  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Grid of options
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
                children: [
                  _AttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFFDB2777),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: const Color(0xFF2563EB),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Document sharing coming soon!')),
                      );
                    },
                  ),
                  _AttachOption(
                    icon: Icons.headphones_rounded,
                    label: 'Audio',
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Audio sharing coming soon!')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
    if (_isUploadingVoice) return;

    setState(() => _isUploadingVoice = true);

    try {
      final file = File(path);
      if (!await file.exists()) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('group_audio')
          .child(widget.groupId)
          .child('${DateTime.now().millisecondsSinceEpoch}.m4a');

      await ref.putFile(file);
      final url = await ref.getDownloadURL();

      widget.bloc.add(GroupChatSendMessage(
        senderId: widget.currentUserId,
        senderName: widget.currentUserName,
        senderAvatarUrl: widget.currentUserAvatarUrl,
        text: '',
        messageType: GroupMessageType.audio,
        audioDuration: durationSeconds,
        mediaUrls: [url],
        replyToMessageId: widget.replyingTo?.id,
        replyToText: widget.replyingTo?.text,
        replyToSenderId: widget.replyingTo?.senderId,
        replyToSenderName: widget.replyingTo?.senderName,
      ));
      widget.onCancelReply();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingVoice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredMembers
        .where((m) => m.userId != widget.currentUserId)
        .toList();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Mention suggestion panel ────────────────────────────────
          if (_isMentioning && filtered.isNotEmpty)
            _MentionSuggestionPanel(
              members: filtered,
              isDark: isDark,
              onSelect: _selectMention,
            ),

          // ── Reply preview ───────────────────────────────────────────
          if (widget.replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.primary.withValues(alpha: 0.05),
                border: Border(
                  left: BorderSide(color: AppTheme.primary, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.replyingTo!.senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.replyingTo!.text.isNotEmpty
                              ? widget.replyingTo!.text
                              : 'Media',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                    onPressed: widget.onCancelReply,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          // ── Main input row ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                final showMicHold = widget.canSend &&
                    !hasText &&
                    (!_isRecordingVoice || !_isVoiceLocked);

                final row = IgnorePointer(
                  ignoring: _isRecordingVoice,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [

                      // ── Luxury Attach Button ─────────────────────────
                      if (widget.canSend)
                        _LuxuryAttachButton(
                          isDark: isDark,
                          isUploading: _isUploadingMedia,
                          onTap: _isUploadingMedia ? null : _showAttachmentMenu,
                        ),

                      if (widget.canSend) const SizedBox(width: 10),

                      // ── Glowing Glass TextField ──────────────────────
                      Expanded(
                        child: _GlowingGlassField(
                          controller: widget.controller,
                          focusNode: _focusNode,
                          isFocused: _isFocused,
                          isDark: isDark,
                          canSend: widget.canSend,
                          isRecording: _isRecordingVoice,
                          isUploadingMedia: _isUploadingMedia,
                          onTextChanged: _onTextChanged,
                          onCameraPressed: () =>
                              _pickAndSendImage(ImageSource.camera),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // ── Send / Mic ────────────────────────────────────
                      if (hasText)
                        _LuxurySendButton(
                          isSending: widget.isSending || _isUploadingVoice,
                          canSend: widget.canSend,
                          onTap: widget.canSend
                              ? () {
                                  widget.onSend(
                                    mentionedUserIds:
                                        List<String>.from(_mentionedUserIds),
                                  );
                                  _mentionedUserIds.clear();
                                  setState(() => _isMentioning = false);
                                }
                              : null,
                        )
                      else
                        const SizedBox(width: 48, height: 48),
                    ],
                  ),
                );

                final isRtl = Directionality.of(context) == TextDirection.rtl;

                return Stack(
                  alignment: isRtl ? Alignment.bottomLeft : Alignment.bottomRight,
                  children: [
                    row,
                    if (_isRecordingVoice)
                      Positioned.fill(
                        child: VoiceRecorderBar(
                          key: _voiceRecorderKey,
                          showMicButton: false,
                          onSend: _sendVoiceMessage,
                          onCancel: () => setState(() {
                            _isRecordingVoice = false;
                            _isVoiceLocked = false;
                          }),
                          onStateChanged: (isRec) {
                            if (!mounted) return;
                            if (!isRec) {
                              setState(() {
                                _isRecordingVoice = false;
                                _isVoiceLocked = false;
                              });
                            }
                          },
                        ),
                      ),
                    if (showMicHold)
                      Positioned(
                        right: isRtl ? null : 0,
                        left: isRtl ? 0 : null,
                        bottom: 0,
                        child: _BreathingMicButton(
                          voiceRecorderKey: _voiceRecorderKey,
                          onStart: () => setState(() {
                            _isRecordingVoice = true;
                            _isVoiceLocked = false;
                            _voiceHoldFinished = false;
                          }),
                          onMoveUpdate: (details) {
                            final bar = _voiceRecorderKey.currentState;
                            if (bar == null) return;
                            bar.handleDragUpdate(
                              dx: details.offsetFromOrigin.dx,
                              dy: details.offsetFromOrigin.dy,
                            );
                            if (!_isVoiceLocked && bar.isLocked) {
                              setState(() => _isVoiceLocked = true);
                            }
                          },
                          onEnd: () {
                            if (_voiceHoldFinished) return;
                            _voiceHoldFinished = true;
                            final bar = _voiceRecorderKey.currentState;
                            if (bar != null && !bar.isLocked) bar.stopAndSend();
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Luxury Sub-widgets for Premium Redesign ───────────────────────────────────

class _LuxuryAttachButton extends StatefulWidget {
  final bool isDark;
  final bool isUploading;
  final VoidCallback? onTap;

  const _LuxuryAttachButton({
    required this.isDark,
    required this.isUploading,
    this.onTap,
  });

  @override
  State<_LuxuryAttachButton> createState() => _LuxuryAttachButtonState();
}

class _LuxuryAttachButtonState extends State<_LuxuryAttachButton> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scale;
  late Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _rotate = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animCtrl.forward(),
      onTapUp: (_) {
        _animCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _animCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: RotationTransition(
              turns: _rotate,
              child: child,
            ),
          );
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

class _GlowingGlassField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final bool isDark;
  final bool canSend;
  final bool isRecording;
  final bool isUploadingMedia;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onCameraPressed;

  const _GlowingGlassField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.isDark,
    required this.canSend,
    required this.isRecording,
    required this.isUploadingMedia,
    required this.onTextChanged,
    required this.onCameraPressed,
  });

  @override
  State<_GlowingGlassField> createState() => _GlowingGlassFieldState();
}

class _GlowingGlassFieldState extends State<_GlowingGlassField> with SingleTickerProviderStateMixin {
  late AnimationController _cameraAnimCtrl;
  late Animation<double> _cameraScale;

  @override
  void initState() {
    super.initState();
    _cameraAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _cameraScale = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _cameraAnimCtrl, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _cameraAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (widget.isFocused)
            BoxShadow(
              color: const Color(0xFF60A5FA).withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          BoxShadow(
            color: widget.isDark
                ? Colors.black.withValues(alpha: 0.25)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.65),
              border: Border.all(
                color: widget.isFocused
                    ? const Color(0xFF60A5FA).withValues(alpha: 0.6)
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppTheme.primary.withValues(alpha: 0.15)),
                width: widget.isFocused ? 1.5 : 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      enabled: widget.canSend && !widget.isRecording,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: widget.onTextChanged,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: widget.isDark ? Colors.white : AppTheme.textMain,
                        letterSpacing: 0.15,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.canSend
                            ? 'Message...'
                            : 'Only admins can send messages',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: widget.isDark
                              ? Colors.white.withValues(alpha: 0.35)
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.canSend)
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 6),
                    child: GestureDetector(
                      onTapDown: (_) => _cameraAnimCtrl.forward(),
                      onTapUp: (_) {
                        _cameraAnimCtrl.reverse();
                        if (!widget.isUploadingMedia) widget.onCameraPressed();
                      },
                      onTapCancel: () => _cameraAnimCtrl.reverse(),
                      child: AnimatedBuilder(
                        animation: _cameraAnimCtrl,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _cameraScale.value,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (_cameraAnimCtrl.isAnimating || _cameraAnimCtrl.value > 0.1)
                                    BoxShadow(
                                      color: const Color(0xFFFFB703).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: widget.isUploadingMedia
                            ? const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF94A3B8),
                                ),
                              )
                            : Icon(
                                Icons.camera_alt_rounded,
                                size: 22,
                                color: widget.isDark
                                    ? Colors.white.withValues(alpha: 0.55)
                                    : const Color(0xFF94A3B8),
                              ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LuxurySendButton extends StatefulWidget {
  final bool isSending;
  final bool canSend;
  final VoidCallback? onTap;

  const _LuxurySendButton({
    required this.isSending,
    required this.canSend,
    this.onTap,
  });

  @override
  State<_LuxurySendButton> createState() => _LuxurySendButtonState();
}

class _LuxurySendButtonState extends State<_LuxurySendButton> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animCtrl.forward(),
      onTapUp: (_) {
        _animCtrl.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _animCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _animCtrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: child,
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: widget.canSend
                ? const LinearGradient(
                    colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.canSend ? null : Colors.grey.shade300,
            boxShadow: widget.canSend
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E40AF).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: widget.isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 21,
                  ),
                ),
        ),
      ),
    );
  }
}

class _BreathingMicButton extends StatelessWidget {
  final GlobalKey<VoiceRecorderBarState> voiceRecorderKey;
  final VoidCallback onStart;
  final ValueChanged<LongPressMoveUpdateDetails> onMoveUpdate;
  final VoidCallback onEnd;

  const _BreathingMicButton({
    required this.voiceRecorderKey,
    required this.onStart,
    required this.onMoveUpdate,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        onStart();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          voiceRecorderKey.currentState?.startRecording();
        });
      },
      onLongPressMoveUpdate: onMoveUpdate,
      onLongPressUp: onEnd,
      onLongPressEnd: (_) => onEnd(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF7C3AED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E40AF).withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.mic_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ── Mention Suggestion Panel ──────────────────────────────────────────────────

class _MentionSuggestionPanel extends StatelessWidget {
  final List<GroupMemberEntity> members;
  final bool isDark;
  final void Function(GroupMemberEntity) onSelect;

  const _MentionSuggestionPanel({
    required this.members,
    required this.isDark,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final maxVisible = members.length.clamp(1, 5);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: BoxConstraints(maxHeight: maxVisible * 64.0),
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        shrinkWrap: true,
        itemCount: members.length,
        itemBuilder: (_, i) => _MentionRow(
          member: members[i],
          isDark: isDark,
          onTap: () => onSelect(members[i]),
        ),
      ),
    );
  }
}

class _MentionRow extends StatelessWidget {
  final GroupMemberEntity member;
  final bool isDark;
  final VoidCallback onTap;

  const _MentionRow({
    required this.member,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = (member.avatarUrl ?? '').trim();
    final roleLabel = member.role == GroupRole.owner
        ? 'Owner'
        : member.role == GroupRole.admin
            ? 'Admin'
            : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppTheme.primary.withValues(alpha: 0.08),
        highlightColor: AppTheme.primary.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: avatarUrl.isEmpty
                      ? const LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '@',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              // Name + role
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (roleLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleLabel == 'Owner'
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: roleLabel == 'Owner'
                                ? const Color(0xFFF59E0B)
                                : AppTheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // @ icon hint
              Icon(
                Icons.alternate_email_rounded,
                size: 16,
                color: AppTheme.primary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date);
    String label;
    if (diff.inDays == 0) {
      label = 'Today';
    } else if (diff.inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat.MMMd().format(date);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Divider(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.15)),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.15)),
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final String groupName;
  const _EmptyChat({required this.groupName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to $groupName!',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Send the first message to kick things off.',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

