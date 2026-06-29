import 'package:flutter/material.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/animations.dart';
import 'package:project_test2/features/assistant/presentation/widgets/assistant_sheet.dart';

class FloatingAIAssistant extends StatelessWidget {
  const FloatingAIAssistant({super.key});

  void _openAssistantSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAssistantSheet(context),
      child: ScaleAnimation(
        child: Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}