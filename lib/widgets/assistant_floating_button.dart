import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import '../features/assistant/assistant_sheet.dart';

class DraggableFloatingButton extends StatefulWidget {
  const DraggableFloatingButton({super.key});

  @override
  State<DraggableFloatingButton> createState() => _DraggableFloatingButtonState();
}

class _DraggableFloatingButtonState extends State<DraggableFloatingButton>
    with SingleTickerProviderStateMixin {
  Offset position = const Offset(20, 100); 
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final bottomNavHeight = 100.0;
    
    return Positioned(
      left: position.dx.clamp(0.0, screenSize.width - 70),
      top: position.dy.clamp(
        MediaQuery.of(context).padding.top + kToolbarHeight,
        screenSize.height - bottomNavHeight - 80,
      ),
      child: Draggable(
        feedback: _buildButton(isDragging: true),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildButton(),
        ),
        onDragEnd: (details) {
          setState(() {
            position = Offset(
              details.offset.dx.clamp(0.0, screenSize.width - 70),
              details.offset.dy.clamp(
                MediaQuery.of(context).padding.top + kToolbarHeight,
                screenSize.height - bottomNavHeight - 80,
              ),
            );
          });
        },
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            _showAssistantSheet();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: _buildButton(),
        ),
      ),
    );
  }

  void _showAssistantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const AssistantSheet(),
    );
  }

  Widget _buildButton({bool isDragging = false}) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? 0.9 : (isDragging ? 1.1 : 1.0),
      child: Container(
            width: 64,
            height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
              gradient: AppTheme.accentGradient,
          boxShadow: [
            BoxShadow(
                  color: AppTheme.secondary.withValues(alpha: 0.4 + (_pulseController.value * 0.2)),
                  blurRadius: 15 + (_pulseController.value * 10),
                  spreadRadius: 2 + (_pulseController.value * 3),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
          ],
        ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 32,
            ),
      ),
        );
      },
    );
  }
}