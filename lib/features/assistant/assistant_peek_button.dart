import 'package:flutter/material.dart';
import 'assistant_sheet.dart';

class AssistantPeekButton extends StatefulWidget {
  const AssistantPeekButton({super.key});

  @override
  State<AssistantPeekButton> createState() => _AssistantPeekButtonState();
}

class _AssistantPeekButtonState extends State<AssistantPeekButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;
  bool _pressed = false;
  Offset? _position;
  bool _dragging = false;

  // The visible portion of the icon when snapped to an edge
  static const double _buttonSize = 68.0;
  static const double _peekAmount = 35.0; 

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const AssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topDefault = size.height * 0.55;

    // snap positions: hide all but peekAmount at each edge
    final minLeft = -((_buttonSize - _peekAmount));   // left edge: -28
    final maxLeft = size.width - _peekAmount;          // right edge: screen - 30

    _position ??= Offset(maxLeft, topDefault);

    final paddingTop = MediaQuery.of(context).padding.top + kToolbarHeight;
    final minTop = paddingTop;
    final maxTop = size.height - 120.0;

    final left = _position!.dx.clamp(minLeft, maxLeft);
    final top  = _position!.dy.clamp(minTop,  maxTop);

    return AnimatedPositioned(
      duration: _dragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          _openAssistant();
        },
        onTapCancel: () => setState(() => _pressed = false),
        onPanStart:  (_) => setState(() => _dragging = true),
        onPanUpdate: (d) {
          setState(() {
            _position = Offset(
              _position!.dx + d.delta.dx,
              _position!.dy + d.delta.dy,
            );
          });
        },
        onPanEnd: (_) {
          // snap to whichever edge is closer
          final centre = _position!.dx + _buttonSize / 2;
          final snapX = centre < size.width / 2 ? minLeft : maxLeft;
          final snapY = _position!.dy.clamp(minTop, maxTop);
          setState(() {
            _dragging = false;
            _position = Offset(snapX, snapY);
          });
        },
        child: AnimatedBuilder(
          animation: _float,
          builder: (context, _) {
            return Transform.translate(
              offset: Offset(0, -_float.value),
              child: AnimatedScale(
                scale: _pressed ? 0.91 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  width: _buttonSize,
                  height: _buttonSize,
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    // Gradient ring: purple → cyan
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF8B5CF6),
                        Color(0xFF06B6D4),
                        Color(0xFF8B5CF6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.30),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0F1524),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'lib/assets/images/chatbot.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => Image.asset(
                        'lib/assets/images/techbot.jpeg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
