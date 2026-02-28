import 'dart:ui' as ui;

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

class _ReactionBarState extends State<ReactionBar> with SingleTickerProviderStateMixin {
  final GlobalKey _barKey = GlobalKey();
  late final AnimationController _controller;
  int _hovered = -1;

  Alignment _alignFor(int idx) {
    if (idx == 0) return Alignment.centerLeft;
    if (idx == 1) return Alignment.center;
    return Alignment.centerRight;
  }

  String _emojiFor(int idx) {
    if (idx == 0) return '😂';
    if (idx == 1) return '❤️';
    return '👍';
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHovered(int index) {
    if (_hovered == index) return;
    setState(() => _hovered = index);
    HapticFeedback.selectionClick();
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
    final type = idx == 0 ? ReactionType.laugh : (idx == 1 ? ReactionType.support : ReactionType.like);
    widget.onSelect(type);
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(scale),
        child: GestureDetector(
          key: _barKey,
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) => _updateFromGlobal(d.globalPosition),
          onPanUpdate: (d) => _updateFromGlobal(d.globalPosition),
          onPanEnd: (_) => _commit(),
          onTapDown: (d) => _updateFromGlobal(d.globalPosition),
          onTapUp: (_) => _commit(),
          onTapCancel: () => _setHovered(-1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SizedBox(
                  height: 56,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_hovered >= 0)
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          alignment: _alignFor(_hovered),
                          child: FractionallySizedBox(
                            widthFactor: 1 / 3,
                            heightFactor: 1,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ),
                      Row(
                        children: List.generate(3, (i) {
                          final active = _hovered == i;
                          return Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() => _hovered = i);
                                  HapticFeedback.lightImpact();
                                  _commit();
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Center(
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    scale: active ? 1.18 : 1.0,
                                    child: Text(
                                      _emojiFor(i),
                                      style: TextStyle(
                                        fontSize: active ? 30 : 26,
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
        ),
      ),
    );
  }
}

