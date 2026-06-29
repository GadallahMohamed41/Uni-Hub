import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
<<<<<<< HEAD
import 'package:intl/intl.dart' hide TextDirection;

import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:project_test2/features/chat/presentation/bloc/messages_bloc/messages_bloc.dart';
import 'package:project_test2/features/chat/presentation/bloc/messages_bloc/messages_event.dart';
import 'package:project_test2/features/chat/presentation/bloc/messages_bloc/messages_state.dart';
import 'package:project_test2/features/chat/presentation/widgets/message_bubble.dart';
import 'package:project_test2/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:project_test2/features/chat/presentation/widgets/voice_recorder_bar.dart';
import 'package:project_test2/features/chat/presentation/widgets/mute_bottom_sheet.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_bloc.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_event.dart';
import 'package:project_test2/features/chat/presentation/bloc/conversations_bloc/conversations_state.dart';
import 'package:project_test2/features/chat/domain/entities/message_entity.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
=======
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../providers/auth_provider.dart';
import 'package:flutter/services.dart';
import '../../../../services/storage_service.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../bloc/messages_bloc/messages_bloc.dart';
import '../bloc/messages_bloc/messages_event.dart';
import '../bloc/messages_bloc/messages_state.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/voice_recorder_bar.dart';
import '../widgets/mute_bottom_sheet.dart';
import '../bloc/conversations_bloc/conversations_bloc.dart';
import '../bloc/conversations_bloc/conversations_event.dart';
import '../bloc/conversations_bloc/conversations_state.dart';
import '../../domain/entities/message_entity.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class DirectMessageScreen extends StatelessWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;

  const DirectMessageScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final myId = context.select<AuthProvider, String?>((auth) => auth.userId) ?? '';
    if (myId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return BlocProvider(
      create: (_) => MessagesBloc(repository: ChatRepositoryImpl())
        ..add(MessagesStarted(
          conversationId: conversationId,
          myUserId: myId,
        )),
      child: _DirectMessageView(
        conversationId: conversationId,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
        myId: myId,
      ),
    );
  }
}

// ── Inner stateful view ───────────────────────────────────────────────────────

class _DirectMessageView extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String myId;

  const _DirectMessageView({
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserAvatar,
    required this.myId,
  });

  @override
  State<_DirectMessageView> createState() => _DirectMessageViewState();
}

class _DirectMessageViewState extends State<_DirectMessageView>
    with WidgetsBindingObserver {
  late MessagesBloc _messagesBloc;
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final GlobalKey<VoiceRecorderBarState> _voiceBarKey =
      GlobalKey<VoiceRecorderBarState>();
  bool _isVoiceLocked = false;
  bool _voiceHoldFinished = false;

  // Typing debounce
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isRecordingVoice = false;
  final bool _isUploadingMedia = false;
  final _storage = StorageService();

  // Message selection
  String? _selectedMessageId;
  String? _lastErrorShown;
<<<<<<< HEAD
  bool _isSearchingMessages = false;
  String _messageSearchQuery = '';
=======
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

  @override
  void initState() {
    super.initState();
    _messagesBloc = context.read<MessagesBloc>();
    WidgetsBinding.instance.addObserver(this);
    _scrollCtrl.addListener(_onScroll);
    _focusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.currentUser == null) {
        auth.checkAuthState();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── App lifecycle: mark seen when app comes to foreground ─────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<MessagesBloc>().add(const MessagesSeen());
<<<<<<< HEAD
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isRecordingVoice && !_isVoiceLocked) {
        setState(() {
          _isVoiceLocked = true;
        });
      }
      _voiceBarKey.currentState?.handleInterruption();
=======
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
    }
  }

  // ── Focus: mark seen when input focused ───────────────────────────────────
  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      context.read<MessagesBloc>().add(const MessagesSeen());
    }
  }

  // ── Scroll: load more messages when reaching the top ─────────────────────
  void _onScroll() {
    if (_scrollCtrl.position.pixels <=
        _scrollCtrl.position.minScrollExtent + 100) {
      context.read<MessagesBloc>().add(const MessagesLoadMore());
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  // ── Typing indicator handling ─────────────────────────────────────────────
  void _onInputChanged(String _) {
    if (!_isTyping) {
      _isTyping = true;
      context.read<MessagesBloc>().add(const TypingStatusChanged(true));
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      _isTyping = false;
      context.read<MessagesBloc>().add(const TypingStatusChanged(false));
    });
  }

  // ── Send message ──────────────────────────────────────────────────────────
  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final state = _messagesBloc.state;
    MessageEntity? replyingTo;
    if (state is MessagesLoaded) {
      replyingTo = state.replyingTo;
    }

    final sender = _resolveSender();
    if (sender == null) {
      _showSnack('جاري تحميل الحساب… حاول مرة تانية');
      return;
    }
    final otherId = _effectiveOtherUserId(sender.id);
    if (otherId.isEmpty) {
      _showSnack('مش قادر أحدد المستخدم التاني للشات');
      return;
    }

    _msgCtrl.clear();
    _typingTimer?.cancel();
    _isTyping = false;

    _messagesBloc.add(MessageSent(
          text: text,
          participantIds: [sender.id, otherId],
          senderId: sender.id,
          senderName: sender.name,
          senderAvatar: sender.avatarUrl,
          replyingTo: replyingTo,
        ));
    _scrollToBottom();
    // Mark seen after sending
    context.read<MessagesBloc>().add(const MessagesSeen());
  }

  String _generateClientMessageId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rnd = Random.secure().nextInt(1 << 32).toRadixString(16);
    return 'local_${ts}_$rnd';
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  _SenderInfo? _resolveSender() {
    final auth = context.read<AuthProvider>();
    final me = auth.currentUser;
    if (me != null) {
      return _SenderInfo(id: me.uid, name: me.name, avatarUrl: me.avatarUrl);
    }

    final fb = fb_auth.FirebaseAuth.instance.currentUser;
    final uid = fb?.uid;
    if (uid == null || uid.trim().isEmpty) return null;
    final displayName = (fb?.displayName ?? '').trim();
    final email = (fb?.email ?? '').trim();
    final fallbackName =
        displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email.split('@').first : 'User');
    return _SenderInfo(id: uid, name: fallbackName, avatarUrl: fb?.photoURL);
  }

  String _effectiveOtherUserId(String myId) {
    final other = widget.otherUserId.trim();
    if (other.isNotEmpty) return other;
    final convId = widget.conversationId.trim();
    if (convId.isEmpty) return '';
    if (convId.startsWith('${myId}_')) {
      return convId.substring(myId.length + 1);
    }
    if (convId.endsWith('_$myId')) {
      return convId.substring(0, convId.length - myId.length - 1);
    }
    final firstUnderscore = convId.indexOf('_');
    final lastUnderscore = convId.lastIndexOf('_');
    if (firstUnderscore <= 0 || firstUnderscore != lastUnderscore) return '';
    final left = convId.substring(0, firstUnderscore);
    final right = convId.substring(firstUnderscore + 1);
    if (left == myId) return right;
    if (right == myId) return left;
    return '';
  }

  Future<void> _sendVoiceMessage(String path, int durationSeconds) async {
    setState(() => _isRecordingVoice = false);
    final sender = _resolveSender();
    if (sender == null) {
      _showSnack('جاري تحميل الحساب… حاول مرة تانية');
      return;
    }
    final otherId = _effectiveOtherUserId(sender.id);
    if (otherId.isEmpty) {
      _showSnack('مش قادر أحدد المستخدم التاني للشات');
      return;
    }

    final state = _messagesBloc.state;
    MessageEntity? replyingTo;
    if (state is MessagesLoaded) {
      replyingTo = state.replyingTo;
    }

    String? localMessageId;
    try {
      final file = File(path);
      if (!await file.exists()) return;

      localMessageId = _generateClientMessageId();
      final createdAt = DateTime.now();
      final localMessage = MessageEntity(
        id: localMessageId,
        conversationId: widget.conversationId,
        senderId: sender.id,
        senderName: sender.name,
        senderAvatarUrl: sender.avatarUrl,
        text: '',
        mediaUrls: const [],
        audioUrl: null,
        audioDuration: durationSeconds,
        messageType: ChatMessageType.audio,
        createdAt: createdAt,
        status: MessageStatus.sending,
        replyToMessageId: replyingTo?.id,
        replyToText: replyingTo?.text,
        replyToSenderId: replyingTo?.senderId,
        replyToSenderName: replyingTo?.senderName,
      );
      _messagesBloc.add(LocalMessageUpserted(localMessage));
      _scrollToBottom();

      final url = await _storage.uploadChatAudio(file);
      if (url == null) throw Exception('Upload failed');

      if (!mounted) return;
      _messagesBloc.add(LocalMessageUpserted(localMessage.copyWith(audioUrl: url)));
      _messagesBloc.add(MessageSent(
            messageId: localMessageId,
            text: '',
            participantIds: [sender.id, otherId],
            senderId: sender.id,
            senderName: sender.name,
            senderAvatar: sender.avatarUrl,
            audioUrl: url,
            audioDuration: durationSeconds,
            messageType: ChatMessageType.audio,
            replyingTo: replyingTo,
          ));
      _scrollToBottom();
      context.read<MessagesBloc>().add(const MessagesSeen());
    } catch (e) {
      if (localMessageId != null) {
        _messagesBloc.add(LocalMessageRemoved(localMessageId));
      }
<<<<<<< HEAD
      debugPrint('Error sending voice message: $e');
      _showSnack('فشل إرسال الرسالة الصوتية. يرجى التحقق من الاتصال بالإنترنت والمحاولة مجدداً.');
=======
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send voice message: $e')),
        );
      }
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final avatarUrl = (widget.otherUserAvatar ?? '').trim();

    return BlocListener<MessagesBloc, MessagesState>(
      listenWhen: (prev, curr) {
        if (curr is MessagesLoaded && curr.error != null) return true;
        return false;
      },
      listener: (context, state) {
        if (state is! MessagesLoaded) return;
        final err = state.error;
        if (err == null) return;
        if (err == _lastErrorShown) return;
        _lastErrorShown = err;
        _showSnack(err);
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
        appBar: _buildAppBar(isDark, avatarUrl),
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(child: _buildMessageList(isDark, theme)),
                    _buildInputBar(isDark, theme),
                  ],
                ),
              ),
            ),
            if (_isUploadingMedia)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, String avatarUrl) {
    ConversationsBloc? conversationsBloc;
    try {
      conversationsBloc = context.read<ConversationsBloc>();
    } catch (_) {
      conversationsBloc = null;
    }

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF111827) : AppTheme.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
<<<<<<< HEAD
      title: _isSearchingMessages
          ? TextField(
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: const InputDecoration(
                hintText: 'البحث في الرسائل...',
                hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() {
                  _messageSearchQuery = val.trim();
                });
              },
            )
          : GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserProfileScreen(userId: widget.otherUserId),
                  ),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: avatarUrl.isNotEmpty
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? Text(
                              widget.otherUserName.isNotEmpty
                                  ? widget.otherUserName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BlocBuilder<MessagesBloc, MessagesState>(
                      buildWhen: (prev, curr) {
                        if (prev is MessagesLoaded && curr is MessagesLoaded) {
                          return prev.isOtherTyping != curr.isOtherTyping;
                        }
                        return false;
                      },
                      builder: (_, state) {
                        final isTyping =
                            state is MessagesLoaded && state.isOtherTyping;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.otherUserName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (conversationsBloc != null)
                                  BlocBuilder<ConversationsBloc, ConversationsState>(
                                    bloc: conversationsBloc,
                                    builder: (context, convState) {
                                      if (convState is ConversationsLoaded) {
                                        try {
                                          final conv = convState.conversations
                                              .firstWhere((c) =>
                                                  c.id == widget.conversationId);
                                          if (conv.isMuted(widget.myId)) {
                                            return const Padding(
                                              padding: EdgeInsets.only(left: 6),
                                              child: Icon(Icons.volume_off_rounded,
                                                  size: 14, color: Colors.white70),
                                            );
                                          }
                                        } catch (_) {}
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: isTyping
                                  ? Text(
                                      'typing...',
                                      key: const ValueKey('typing'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  : Text(
                                      'tap to view profile',
                                      key: const ValueKey('online'),
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchingMessages ? Icons.close_rounded : Icons.search_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            setState(() {
              _isSearchingMessages = !_isSearchingMessages;
              if (!_isSearchingMessages) {
                _messageSearchQuery = '';
              }
            });
          },
        ),
        if (conversationsBloc != null && !_isSearchingMessages)
=======
      title: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: BlocBuilder<MessagesBloc, MessagesState>(
              buildWhen: (prev, curr) {
                if (prev is MessagesLoaded && curr is MessagesLoaded) {
                  return prev.isOtherTyping != curr.isOtherTyping;
                }
                return false;
              },
              builder: (_, state) {
                final isTyping =
                    state is MessagesLoaded && state.isOtherTyping;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.otherUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversationsBloc != null)
                          BlocBuilder<ConversationsBloc, ConversationsState>(
                            bloc: conversationsBloc,
                            builder: (context, convState) {
                              if (convState is ConversationsLoaded) {
                                try {
                                  final conv = convState.conversations
                                      .firstWhere((c) =>
                                          c.id == widget.conversationId);
                                  if (conv.isMuted(widget.myId)) {
                                    return const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.volume_off_rounded,
                                          size: 14, color: Colors.white70),
                                    );
                                  }
                                } catch (_) {}
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isTyping
                          ? Text(
                              'typing...',
                              key: const ValueKey('typing'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : Text(
                              'tap to view profile',
                              key: const ValueKey('online'),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        if (conversationsBloc != null)
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
          BlocBuilder<ConversationsBloc, ConversationsState>(
            bloc: conversationsBloc,
            builder: (context, convState) {
              bool isMuted = false;
              if (convState is ConversationsLoaded) {
                try {
                  final conv = convState.conversations
                      .firstWhere((c) => c.id == widget.conversationId);
                  isMuted = conv.isMuted(widget.myId);
                } catch (_) {}
              }
              return IconButton(
                icon: Icon(
                  isMuted
                      ? Icons.notifications_off_rounded
                      : Icons.more_vert_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  MuteBottomSheet.show(
                    context,
                    isCurrentlyMuted: isMuted,
                    onMuteSelected: (muteUntil) {
                      context.read<ConversationsBloc>().add(
                            ConversationsMuteConversation(
                              conversationId: widget.conversationId,
                              userId: widget.myId,
                              muteUntil: muteUntil,
                            ),
                          );
                    },
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildMessageList(bool isDark, ThemeData theme) {
    return BlocConsumer<MessagesBloc, MessagesState>(
      listenWhen: (prev, curr) =>
          prev is! MessagesLoaded && curr is MessagesLoaded,
      listener: (_, state) {
        if (state is MessagesLoaded) {
          // First load: jump to bottom
          _scrollToBottom(animated: false);
          // Mark seen
          context.read<MessagesBloc>().add(const MessagesSeen());
        }
      },
      builder: (_, state) {
        if (state is MessagesInitial) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text(
                  'جاري تحميل الرسائل...',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        if (state is MessagesLoading) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text(
                  'جاري تحميل الرسائل...',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        if (state is MessagesError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'حصلت مشكلة في تحميل المحادثة',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: const TextStyle(color: AppTheme.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      context.read<MessagesBloc>().add(
                            MessagesStarted(
                              conversationId: widget.conversationId,
                              myUserId: widget.myId,
                            ),
                          );
                    },
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state is MessagesLoaded) {
          final messages = state.messages
              .where((m) => !(m.deletedForMe.contains(widget.myId) && !m.deletedForAll))
              .toList();

<<<<<<< HEAD
          final filteredMessages = _messageSearchQuery.isEmpty
              ? messages
              : messages
                  .where((m) =>
                      m.text.toLowerCase().contains(_messageSearchQuery.toLowerCase()))
                  .toList();

          if (filteredMessages.isEmpty && !state.isOtherTyping) {
=======
          if (messages.isEmpty && !state.isOtherTyping) {
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
            return _buildEmptyState(isDark, theme);
          }

          final topLoaderCount = state.isLoadingMore ? 1 : 0;
          final typingCount = state.isOtherTyping ? 1 : 0;
<<<<<<< HEAD
          final totalCount = topLoaderCount + filteredMessages.length + typingCount;
=======
          final totalCount = topLoaderCount + messages.length + typingCount;
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

          return ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            itemCount: totalCount,
            itemBuilder: (ctx, i) {
              if (state.isLoadingMore && i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final messageIndex = i - topLoaderCount;
<<<<<<< HEAD
              final isTypingRow = state.isOtherTyping && messageIndex == filteredMessages.length;
=======
              final isTypingRow = state.isOtherTyping && messageIndex == messages.length;
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
              if (isTypingRow) {
                return const TypingIndicator();
              }

<<<<<<< HEAD
              final msg = filteredMessages[messageIndex];
              final isMe = msg.senderId == widget.myId;
              final showDate = messageIndex == 0 ||
                  _formatDate(filteredMessages[messageIndex - 1].createdAt) !=
=======
              final msg = messages[messageIndex];
              final isMe = msg.senderId == widget.myId;
              final showDate = messageIndex == 0 ||
                  _formatDate(messages[messageIndex - 1].createdAt) !=
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
                      _formatDate(msg.createdAt);

              return Column(
                children: [
                  if (showDate) _buildDateDivider(msg.createdAt, isDark),
                  MessageBubble(
                    message: msg,
                    isMe: isMe,
                    isDark: isDark,
                    enableReactions: true,
                    compact: true,
                    showAvatar: !isMe &&
<<<<<<< HEAD
                        (messageIndex == filteredMessages.length - 1 ||
                            filteredMessages[messageIndex + 1].senderId != msg.senderId),
=======
                        (messageIndex == messages.length - 1 ||
                            messages[messageIndex + 1].senderId != msg.senderId),
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
                    otherUserName: widget.otherUserName,
                    otherUserAvatar: widget.otherUserAvatar,
                    isSelected: _selectedMessageId == msg.id,
                    currentUserId: widget.myId,
                    onLongPress: () {
                      setState(() {
                        _selectedMessageId =
                            _selectedMessageId == msg.id ? null : msg.id;
                      });
                    },
                    onReply: (m) => _messagesBloc.add(MessageReplySet(m)),
                    onEdit: (m) {
                      final ctrl = TextEditingController(text: m.text);
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Edit Message'),
                          content: TextField(
                            controller: ctrl,
                            decoration: const InputDecoration(
                              hintText: 'Enter new text...',
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                if (ctrl.text.trim().isNotEmpty) {
                                  _messagesBloc.add(MessageEdited(
                                    messageId: m.id,
                                    newText: ctrl.text.trim(),
                                  ));
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDelete: (m, forEveryone) {
                      if (forEveryone) {
                        _messagesBloc.add(MessageDeletedForEveryone(m.id));
                      } else {
                        _messagesBloc.add(MessageDeletedForMe(m.id));
                      }
                    },
                    onReact: (m, emoji) {
                      _messagesBloc.add(MessageReacted(messageId: m.id, emoji: emoji));
                    },
                    onCopy: (m) {},
                  ),
                ],
              );
            },
          );
        }

        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text(
                'جاري تحميل الرسائل...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme) {
    final avatarUrl = (widget.otherUserAvatar ?? '').trim();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: CircleAvatar(
              radius: 40,
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : AppTheme.surfaceVariant,
              backgroundImage: avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      widget.otherUserName.isNotEmpty
                          ? widget.otherUserName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.otherUserName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a conversation!',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _msgCtrl,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;

          final baseRow = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAttachmentMenu();
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded,
                      color: isDark ? Colors.white70 : Colors.black54, size: 24),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BlocBuilder<MessagesBloc, MessagesState>(
                  builder: (context, state) {
                    final replyingTo =
                        state is MessagesLoaded ? state.replyingTo : null;
                    return Container(
                      constraints: const BoxConstraints(maxHeight: 140),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppTheme.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (replyingTo != null)
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24)),
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyingTo.senderName,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primary,
                                          ),
                                        ),
                                        Text(
                                          replyingTo.text.isEmpty
                                              ? 'Media'
                                              : replyingTo.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _messagesBloc
                                        .add(const MessageReplySet(null)),
                                    child: Icon(Icons.close_rounded,
                                        size: 18,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                          Flexible(
                            child: TextField(
                              controller: _msgCtrl,
                              focusNode: _focusNode,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Write a message...',
                                hintStyle: const TextStyle(
                                    color: AppTheme.textTertiary, fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                filled: false,
                              ),
                              onChanged: _onInputChanged,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (hasText)
                BlocBuilder<MessagesBloc, MessagesState>(
                  buildWhen: (p, c) {
                    final pSending = p is MessagesLoaded && p.isSending;
                    final cSending = c is MessagesLoaded && c.isSending;
                    return pSending != cSending;
                  },
                  builder: (_, state) {
                    final isSending =
                        state is MessagesLoaded && state.isSending;
                    return GestureDetector(
                      onTap: isSending ? null : _sendMessage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: isSending ? null : AppTheme.primaryGradient,
                          color: isSending ? AppTheme.textTertiary : null,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: isSending
                            ? const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white, size: 20),
                      ),
                    );
                  },
                )
              else
                const SizedBox(width: 46, height: 46),
            ],
          );

          final recorder = VoiceRecorderBar(
            key: _voiceBarKey,
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
          );

          final showMicHold = !hasText && (!_isRecordingVoice || !_isVoiceLocked);
<<<<<<< HEAD
          final isRtl = Directionality.of(context) == TextDirection.rtl;

          return Stack(
            alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
=======

          return Stack(
            alignment: Alignment.centerLeft,
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
            children: [
              if (_isRecordingVoice) recorder else baseRow,
              if (showMicHold)
                Positioned(
<<<<<<< HEAD
                  right: isRtl ? null : 0,
                  left: isRtl ? 0 : null,
=======
                  right: 0,
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
                  bottom: 0,
                  child: GestureDetector(
                    onLongPressStart: (_) {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _isRecordingVoice = true;
                        _isVoiceLocked = false;
                        _voiceHoldFinished = false;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _voiceBarKey.currentState?.startRecording();
                      });
                    },
                    onLongPressMoveUpdate: (details) {
                      final bar = _voiceBarKey.currentState;
                      if (bar == null) return;
                      bar.handleDragUpdate(
                        dx: details.offsetFromOrigin.dx,
                        dy: details.offsetFromOrigin.dy,
                      );
                      if (!_isVoiceLocked && bar.isLocked) {
                        setState(() => _isVoiceLocked = true);
                      }
                    },
                    onLongPressUp: () {
                      if (_voiceHoldFinished) return;
                      _voiceHoldFinished = true;
                      final bar = _voiceBarKey.currentState;
                      if (bar == null) return;
                      if (!bar.isLocked) {
                        bar.stopAndSend();
                      }
                    },
                    onLongPressEnd: (_) {
                      if (_voiceHoldFinished) return;
                      _voiceHoldFinished = true;
                      final bar = _voiceBarKey.currentState;
                      if (bar == null) return;
                      if (!bar.isLocked) {
                        bar.stopAndSend();
                      }
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: isDark ? Colors.white70 : Colors.black54,
                        size: 22,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file == null) return;

    try {
      final url = await _storage.uploadChatImage(File(file.path));
      if (url != null) {
        final sender = _resolveSender();
        if (sender == null) {
          if (!mounted) return;
          _showSnack('جاري تحميل الحساب… حاول مرة تانية');
          return;
        }
        final otherId = _effectiveOtherUserId(sender.id);
        if (otherId.isEmpty) {
          if (!mounted) return;
          _showSnack('مش قادر أحدد المستخدم التاني للشات');
          return;
        }
        final state = _messagesBloc.state;
        final reply = state is MessagesLoaded ? state.replyingTo : null;

        _messagesBloc.add(MessageSent(
          participantIds: [sender.id, otherId],
          senderId: sender.id,
          senderName: sender.name,
          senderAvatar: sender.avatarUrl,
          text: '',
          messageType: ChatMessageType.image,
          mediaUrls: [url],
          replyingTo: reply,
        ));
        _messagesBloc.add(const MessageReplySet(null));
      }
    } catch (e) {
<<<<<<< HEAD
      debugPrint('Error sending image: $e');
      _showSnack('فشل إرسال الصورة. يرجى التحقق من الاتصال بالإنترنت والمحاولة مجدداً.');
=======
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c
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
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 20,
                crossAxisSpacing: 10,
                children: [
                  _AttachmentOption(
                    icon: Icons.image_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.gallery);
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: const Color(0xFFEC4899),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndSendImage(ImageSource.camera);
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
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
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
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SenderInfo {
  final String id;
  final String name;
  final String? avatarUrl;
  const _SenderInfo({required this.id, required this.name, this.avatarUrl});
}
