import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/reactions.dart';

class ReactionBar extends StatefulWidget {
  final void Function(ReactionType type) onSelect;

  const ReactionBar({
    super.key,
    required this.onSelect,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar>
    with SingleTickerProviderStateMixin {
  final GlobalKey _barKey = GlobalKey();
  late final AnimationController _controller;
  int _hovered = -1;

  // Elegant color palette
  static const _bgColor = Color(0xFFFFFFFF);
  static const _shadowColor = Color(0x1A000000);
  static const _borderColor = Color(0x0F000000);
  static const _hoverBgColor = Color(0xFFF5F5F5);
  static const _rippleColor = Color(0x15000000);

  final List<String> _emojis = ['😂', '❤️', '👍'];
  final List<Color> _emojiAccents = [
    const Color(0xFFFFD93D), 
    const Color(0xFFFF6B6B),
    const Color(0xFF4ECDC4), 
  ];

  Alignment _alignFor(int idx) {
    if (idx == 0) return Alignment.centerLeft;
    if (idx == 1) return Alignment.center;
    return Alignment.centerRight;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHovered(int index) {
    if (_hovered == index) return;
    setState(() => _hovered = index);
    if (index >= 0) {
      HapticFeedback.selectionClick();
    }
  }

  void _updateFromGlobal(Offset globalPosition) {
    final ctx = _barKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final local = box.globalToLocal(globalPosition);
    final w = box.size.width;
    final h = box.size.height;
    if (local.dx < 0 || local.dx > w || local.dy < 0 || local.dy > h) {
      _setHovered(-1);
      return;
    }
    final itemW = w / 3;
    final idx = (local.dx / itemW).floor().clamp(0, 2);
    _setHovered(idx);
  }

  void _commit() {
    final idx = _hovered;
    if (idx < 0) return;
    final type = idx == 0
        ? ReactionType.laugh
        : (idx == 1 ? ReactionType.support : ReactionType.like);
    HapticFeedback.mediumImpact();
    widget.onSelect(type);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final scale =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.88, end: 1.0).animate(scale),
        child: GestureDetector(
          key: _barKey,
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _updateFromGlobal(d.globalPosition),
          onPanUpdate: (d) => _updateFromGlobal(d.globalPosition),
          onPanEnd: (_) => _commit(),
          onTapDown: (d) => _updateFromGlobal(d.globalPosition),
          onTapUp: (_) => _commit(),
          onTapCancel: () => _setHovered(-1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _borderColor,
                width: 0.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: _shadowColor,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SizedBox(
              height: 38,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Animated highlight background
                  if (_hovered >= 0)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      alignment: _alignFor(_hovered),
                      child: FractionallySizedBox(
                        widthFactor: 1 / 3,
                        heightFactor: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(1),
                          child: Container(
                            decoration: BoxDecoration(
                              color: _hoverBgColor,
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Reaction buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final active = _hovered == i;
                      return Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() => _hovered = i);
                              _commit();
                            },
                            borderRadius: BorderRadius.circular(24),
                            splashColor: _rippleColor,
                            highlightColor: Colors.transparent,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  transform: Matrix4.identity()
                                    ..scaleByDouble(
                                      active ? 1.28 : 1.0,
                                      active ? 1.28 : 1.0,
                                      1.0,
                                      1.0,
                                    ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Subtle accent glow when active
                                      if (active)
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _emojiAccents[i]
                                                .withValues(alpha: 0.12),
                                          ),
                                        ),
                                      // Emoji
                                      Text(
                                        _emojis[i],
                                        style: TextStyle(
                                          fontSize: active ? 24 : 21,
                                          height: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
