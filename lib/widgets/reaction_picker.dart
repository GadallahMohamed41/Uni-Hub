import 'package:flutter/material.dart';

import '../core/reactions.dart';
import 'reaction_bar.dart';

Future<void> showReactionPickerPopover({
  required BuildContext context,
  required Offset globalPosition,
  required void Function(ReactionType type) onSelect,
}) async {
  final overlay = Overlay.of(context);

  OverlayEntry? entry;

  void close() {
    entry?.remove();
    entry = null;
  }

  entry = OverlayEntry(
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      const barWidth = 190.0;
      const barHeight = 60.0;
      const margin = 12.0;

      final left = (globalPosition.dx - (barWidth / 2)).clamp(margin, media.size.width - barWidth - margin);
      final topCandidate = globalPosition.dy - barHeight - 14;
      final top = topCandidate.clamp(media.padding.top + margin, media.size.height - barHeight - margin);

      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: close,
              child: const SizedBox(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: barWidth,
            height: barHeight,
            child: Material(
              color: Colors.transparent,
              child: RepaintBoundary(
                child: ReactionBar(
                  onSelect: (type) {
                    onSelect(type);
                    close();
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
  );

  overlay.insert(entry!);
}

Future<void> showReactionPickerDialog({
  required BuildContext context,
  required void Function(ReactionType type) onSelect,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'reactions',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, __) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: RepaintBoundary(
                child: ReactionBar(
                  onSelect: (type) {
                    onSelect(type);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
