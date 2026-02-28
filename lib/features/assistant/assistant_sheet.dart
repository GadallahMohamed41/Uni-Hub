import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import '../../core/animations.dart';

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({super.key});

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': "Hello! I'm your university assistant. How can I help you today?",
      'isBot': true,
      'time': 'Just now',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    setState(() {
      _messages.add({
        'text': _messageController.text,
        'isBot': false,
        'time': 'Just now',
      });
      _messageController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppTheme.accentGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "AI Assistant",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textMain),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textTertiary),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Container(
                  color: AppTheme.background,
                  child: ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    itemCount: _messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _buildQuickAction("Calendar", Icons.calendar_month_rounded, AppTheme.info),
                              _buildQuickAction("Departments", Icons.apartment_rounded, AppTheme.secondary),
                              _buildQuickAction("Activities", Icons.palette_rounded, AppTheme.warning),
                              _buildQuickAction("Courses", Icons.menu_book_rounded, AppTheme.success),
                            ],
                          ),
                        );
                      }
                      final msgIndex = _messages.length - 1 - index;
                      final message = _messages[msgIndex];
                      return FadeInAnimation(
                        delay: index * 80,
                        child: _buildMessage(message['text'], message['isBot']),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: AppTheme.textMain),
                        decoration: InputDecoration(
                          hintText: "Type your message...",
                          hintStyle: const TextStyle(color: AppTheme.textTertiary),
                          filled: true,
                          fillColor: AppTheme.surfaceVariant,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessage(String text, bool isBot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
          if (isBot) ...[
        Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
        ),
            const SizedBox(width: 12),
          ],
          Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBot ? AppTheme.surface : AppTheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isBot ? 0 : 20),
                  bottomRight: Radius.circular(isBot ? 20 : 0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
            ),
              child: Text(
                text,
                style: TextStyle(
                  color: isBot ? AppTheme.textMain : Colors.white,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
          ),
        ),
          if (!isBot) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
            ),
          ],
      ],
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
