import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import '../../core/animations.dart';
import 'ai_service.dart';
import 'package:uuid/uuid.dart';
import '../../services/chat_storage_service.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import 'widgets/premium_chat_input.dart';

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final TextEditingController _messageController = TextEditingController();
  String _chatId = const Uuid().v4();
  String _apiSessionId = const Uuid().v4();
  final ChatStorageService _chatStorage = ChatStorageService();
  String? _chatTitle;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _chatSearchController = TextEditingController();
  String _chatSearch = '';
  final List<Map<String, dynamic>> _messages = [];
  bool _sending = false;
  bool _aiOnline = true;
  final AiService _ai = AiService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _messages.isNotEmpty) return;
      setState(() {
        _messages.add({
          'text': "مرحباً! أنا مساعد الجامعة الذكي. كيف أقدر أساعدك اليوم؟",
          'isBot': true,
          'time': 'الآن',
        });
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatSearchController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _saveCurrentChat() {
    if (_messages.length <= 1) return;
    if (_chatTitle == null) {
      final firstUserMsg = _messages.firstWhere(
        (m) => m['isBot'] == false,
        orElse: () => {'text': 'محادثة جديدة'},
      );
      _chatTitle = _extractChatTitle((firstUserMsg['text'] ?? '').toString());
    }
    _chatStorage.saveChat({
      'id': _chatId,
      'title': _chatTitle,
      'messages': _messages,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    
    setState(() {
      _messages.add({
        'text': text,
        'isBot': false,
        'time': 'الآن',
      });
      _messageController.clear();
      _sending = true;
    });

    if (_chatTitle == null) {
      _chatTitle = _extractChatTitle(text);
      _saveCurrentChat();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    try {
      String? reply;
      AiApiException? lastApiError;

      const delays = [
        Duration(milliseconds: 0),
        Duration(milliseconds: 700),
        Duration(milliseconds: 1500),
      ];

      for (var attempt = 0; attempt < delays.length; attempt++) {
        if (attempt > 0) {
          await Future.delayed(delays[attempt]);
          _apiSessionId = const Uuid().v4();
        }

        try {
          reply = await _ai.reply(sessionId: _apiSessionId, message: text);
          break;
        } catch (e) {
          if (e is AiApiException) {
            lastApiError = e;
            if ((e.statusCode ?? 0) >= 500) {
              continue;
            }
          }
          rethrow;
        }
      }

      if (reply == null) {
        throw lastApiError ?? const AiApiException(message: 'AI API unavailable');
      }

      setState(() {
        _messages.add({
          'text': reply,
          'isBot': true,
          'time': 'الآن'
        });
        _sending = false;
        _aiOnline = true;
      });
      _saveCurrentChat();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      final msg = (e is AiApiException && e.statusCode != null)
          ? 'خدمة المساعد مشغولة حالياً (خطأ ${e.statusCode}). حاول بعد دقيقة.'
          : 'تعذر الاتصال بالمساعد الآن. حاول مرة أخرى.';
      setState(() {
        _messages.add({
          'text': msg,
          'isBot': true,
          'time': 'الآن'
        });
        _sending = false;
        _aiOnline = false;
      });
      _saveCurrentChat();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const heightFactor = 0.86;
    final keyboard = media.viewInsets.bottom;
    final maxHeight = media.size.height * heightFactor;
    final availableHeight = (media.size.height - keyboard - media.padding.top).clamp(0.0, media.size.height);
    final height = (availableHeight < maxHeight ? availableHeight : maxHeight).clamp(320.0, maxHeight);
    final hasUserMessages = _messages.any((m) => m['isBot'] == false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: keyboard,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: height,
                child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Builder(
                      builder: (ctx) {
                        return IconButton(
                          icon: const Icon(Icons.menu_rounded, color: Colors.white),
                          onPressed: () => Scaffold.of(ctx).openDrawer(),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: _aiOnline ? const Color(0xFF4CAF50) : const Color(0xFFE53935)),
                          SizedBox(width: 6),
                          Text(
                            _aiOnline ? 'متصل' : 'غير متصل',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const Text('Tech', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const Text('Bot', style: TextStyle(color: Color(0xFFFFA726), fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'lib/assets/images/chatbot.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) {
                          return Image.asset('lib/assets/images/techbot.jpeg', fit: BoxFit.cover);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF111827) : theme.scaffoldBackgroundColor,
                  child: hasUserMessages ? _buildChatList() : _buildWelcome(),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  (keyboard > 0 ? 0 : media.padding.bottom + 12),
                ),
                child: _buildInput(keyboardOpen: keyboard > 0),
              ),
              ],
            ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final w = MediaQuery.of(context).size.width;
    return Drawer(
      width: w * 0.84,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 50, 10, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: const Color(0xFF171717),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: const Icon(Icons.smart_toy_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'TechBot',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
                      onPressed: _startNewChat,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                ),
                child: TextField(
                  controller: _chatSearchController,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    hintText: 'ابحث في المحادثات',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.transparent,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white60),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) {
                    setState(() => _chatSearch = v);
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'محادثاتك',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _chatStorage.getChatsDeduped(query: _chatSearch),
                builder: (context, snapshot) {
                  final chats = snapshot.data ?? [];
                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد محادثات بعد',
                        style:
                            const TextStyle(color: Colors.white54, fontSize: 14),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      final title = _extractChatTitle((chat['title'] ?? '...').toString());
                      final id = (chat['id'] ?? '').toString();
                      final selected = id.isNotEmpty && id == _chatId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: selected ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            onTap: () => _loadChat(chat),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.delete_outline, color: Colors.white70, size: 18),
                                      onPressed: () async {
                                        await _chatStorage.deleteChat(chat['id'].toString());
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
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

  void _startNewChat() {
    setState(() {
      _chatId = const Uuid().v4();
      _apiSessionId = const Uuid().v4();
      _chatTitle = null;
      _messages
        ..clear()
        ..add({
          'text': "مرحباً! أنا مساعد الجامعة الذكي. كيف أقدر أساعدك اليوم؟",
          'isBot': true,
          'time': 'الآن',
        });
    });
    Navigator.pop(context);
  }

  void _loadChat(Map<String, dynamic> chat) {
    setState(() {
      _chatId = chat['id'].toString();
      _apiSessionId = _chatId;
      _chatTitle = (chat['title'] ?? '').toString();
      _messages
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(chat['messages'] ?? []));
      if (_messages.isEmpty) {
        _messages.add({
          'text': "مرحباً! أنا مساعد الجامعة الذكي. كيف أقدر أساعدك اليوم؟",
          'isBot': true,
          'time': 'الآن',
        });
      }
    });
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  String _extractChatTitle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'محادثة جديدة';
    final parts = trimmed
        .split(RegExp(r'[\n\r]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final firstLine = parts.isNotEmpty ? parts.first : trimmed;

    final m = RegExp(r'^(.{1,80}?)([\.\!\?\؟\!]|$)').firstMatch(firstLine);
    final title = (m?.group(1) ?? firstLine).trim();
    return title.isEmpty ? 'محادثة جديدة' : title;
  }

  Widget _buildWelcome() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return ListView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
      children: [
        Center(
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12), width: 6),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.accentGradient,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'lib/assets/images/chatbot.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return Image.asset('lib/assets/images/techbot.jpeg', fit: BoxFit.cover);
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'أهلًا بك في ',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const TextSpan(
                  text: 'TechBot',
                  style: TextStyle(color: Color(0xFFFFA726), fontSize: 28, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'مساعدك الذكي للإجابة على كل استفساراتك عن\nجامعة أسيوط الجديدة التكنولوجية',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 15, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 18),
        _buildSuggestion(
          'ما هي الأوراق المطلوبة للتقديم؟',
        ),
        const SizedBox(height: 12),
        _buildSuggestion(
          'ما هي عدد الساعات المطلوبة للتدريب؟',
        ),
        const SizedBox(height: 12),
        _buildSuggestion(
          'الكليات المتاحة في الجامعة',
        ),
      ],
    );
  }

  Widget _buildSuggestion(String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      reverse: false,
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return FadeInAnimation(
          delay: index * 60,
          child: _buildMessage(message['text'], message['isBot']),
        );
      },
    );
  }

  Widget _buildInput({required bool keyboardOpen}) {
    return PremiumChatInput(
      controller: _messageController,
      onSend: _sendMessage,
      isSending: _sending,
      placeholder: 'اسأل TechBot...',
    );
  }

  Widget _buildMessage(String text, bool isBot) {
    final dir = _textDirectionFor(text);
    final align = dir == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isBot) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'lib/assets/images/chatbot.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) {
                  return Image.asset('lib/assets/images/techbot.jpeg', fit: BoxFit.cover);
                },
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isBot 
                    ? (isDark ? const Color(0xFF334155) : Colors.white)
                    : AppTheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 4 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 4),
                ),
                boxShadow: [
                  if (isBot)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Directionality(
                textDirection: dir,
                child: Text(
                  text,
                  textAlign: align,
                  style: TextStyle(
                    color: isBot ? theme.colorScheme.onSurface : Colors.white,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          if (!isBot) ...[
            const SizedBox(width: 12),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  TextDirection _textDirectionFor(String text) {
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(text)) return TextDirection.rtl;
    if (RegExp(r'[A-Za-z]').hasMatch(text)) return TextDirection.ltr;
    return Directionality.of(context);
  }

  Widget _buildUserAvatar() {
    final auth = context.read<AuthProvider>();
    final avatarUrl = (auth.currentUser?.avatarUrl ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.3),
          width: 2,
        ),
        image: hasAvatar 
          ? DecorationImage(
              image: CachedNetworkImageProvider(avatarUrl), 
              fit: BoxFit.cover
            ) 
          : null,
      ),
      child: hasAvatar 
        ? null 
        : const Icon(Icons.person_rounded, color: AppTheme.primary, size: 22),
    );
  }
}
