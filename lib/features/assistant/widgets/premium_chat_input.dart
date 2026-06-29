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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr, // Input field left, send button on the right
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Pill shaped input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: Colors.white,
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
                        color: Colors.white.withValues(alpha: 0.35),
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
