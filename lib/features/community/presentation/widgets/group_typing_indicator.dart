import 'package:flutter/material.dart';
import 'package:project_test2/core/theme/theme.dart';

/// WhatsApp-style typing indicator showing bouncing dots and names.
class GroupTypingIndicator extends StatefulWidget {
  final List<String> typingNames;

  const GroupTypingIndicator({super.key, required this.typingNames});

  @override
  State<GroupTypingIndicator> createState() => _GroupTypingIndicatorState();
}

class _GroupTypingIndicatorState extends State<GroupTypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const _dotCount = 3;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _dotCount,
      (i) => AnimationController(
          vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -7).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();

    for (int i = 0; i < _dotCount; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String get _typingText {
    final names = widget.typingNames;
    if (names.isEmpty) return '';
    if (names.length == 1) return '${names[0]} is typing...';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing...';
    return 'Several people are typing...';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bouncing dots
                Row(
                  children: List.generate(_dotCount, (i) {
                    return AnimatedBuilder(
                      animation: _animations[i],
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _animations[i].value),
                        child: Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                if (widget.typingNames.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    _typingText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white54
                          : Colors.black45,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

