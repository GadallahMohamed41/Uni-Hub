import 'package:flutter/material.dart';

class PremiumChatInput extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final String placeholder;

  const PremiumChatInput({
    super.key,
    required this.controller,
    required this.onSend,
    this.isSending = false,
    this.placeholder = 'اسأل TechBot...',
  });

  @override
  State<PremiumChatInput> createState() => _PremiumChatInputState();
}

class _PremiumChatInputState extends State<PremiumChatInput> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.transparent : Colors.black.withValues(alpha: 0.08),
            width: isDark ? 0 : 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Directionality(
          textDirection: TextDirection.ltr, // Forced LTR layout: Input field left, send button on the right
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pill shaped input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: isDark 
                          ? Colors.white.withValues(alpha: 0.10) 
                          : Colors.black.withValues(alpha: 0.12),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textDirection: TextDirection.rtl, // RTL text input
                    cursorColor: const Color(0xFF2563EB),
                    cursorWidth: 2,
                    decoration: InputDecoration(
                      hintText: widget.placeholder,
                      hintStyle: TextStyle(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.35) 
                            : Colors.black38,
                        fontSize: 14,
                      ),
                      hintTextDirection: TextDirection.rtl, // Right-aligned placeholder
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      if (!widget.isSending) {
                        widget.onSend();
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Circular send button
              _buildSendButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return GestureDetector(
      onTap: () {
        if (!widget.isSending) {
          widget.onSend();
        }
      },
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2563EB),
        ),
        child: Center(
          child: widget.isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
