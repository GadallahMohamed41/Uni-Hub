/// Feeling / Mood selector for the Create Post screen.
///
/// Provides a dropdown of moods (Happy, Sad, Excited, In Love, Tired, Thinking).
/// Displays selected feeling as "[Username] feels [emotion]".
library;

import 'package:flutter/material.dart';

/// Available moods with their emoji and label.
class Feeling {
  final String emoji;
  final String label;
  final String firestoreValue;

  const Feeling({
    required this.emoji,
    required this.label,
    required this.firestoreValue,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Feeling &&
          runtimeType == other.runtimeType &&
          firestoreValue == other.firestoreValue;

  @override
  int get hashCode => firestoreValue.hashCode;
}

/// Predefined list of available feelings.
const List<Feeling> availableFeelings = [
  Feeling(emoji: '😊', label: 'Happy', firestoreValue: 'happy'),
  Feeling(emoji: '😢', label: 'Sad', firestoreValue: 'sad'),
  Feeling(emoji: '🔥', label: 'Excited', firestoreValue: 'excited'),
  Feeling(emoji: '😍', label: 'In Love', firestoreValue: 'in_love'),
  Feeling(emoji: '🥱', label: 'Tired', firestoreValue: 'tired'),
  Feeling(emoji: '🤔', label: 'Thinking', firestoreValue: 'thinking'),
];

/// Returns a Feeling from its Firestore value, or null if not found.
Feeling? feelingFromFirestore(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    return availableFeelings.firstWhere((f) => f.firestoreValue == value);
  } catch (_) {
    return null;
  }
}

/// A chip button that shows the current feeling or opens the selector.
class FeelingChipButton extends StatelessWidget {
  final Feeling? selected;
  final ValueChanged<Feeling?> onChanged;

  const FeelingChipButton({
    super.key,
    this.selected,
    required this.onChanged,
  });

  void _showFeelingPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "How are you feeling?",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              // Feelings grid
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableFeelings.map((feeling) {
                  final isSelected = selected == feeling;
                  return GestureDetector(
                    onTap: () {
                      onChanged(isSelected ? null : feeling);
                      Navigator.pop(ctx);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.5)
                              : colorScheme.outline.withValues(alpha: 0.15),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            feeling.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            feeling.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              // Clear button
              if (selected != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    onChanged(null);
                    Navigator.pop(ctx);
                  },
                  icon: Icon(Icons.clear_rounded,
                      size: 16, color: colorScheme.error),
                  label: Text(
                    "Remove feeling",
                    style: TextStyle(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _showFeelingPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected != null
              ? colorScheme.tertiary.withValues(alpha: 0.1)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected != null
                ? colorScheme.tertiary.withValues(alpha: 0.3)
                : colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected != null) ...[
              Text(selected!.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                selected!.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.tertiary,
                ),
              ),
            ] else ...[
              Icon(Icons.sentiment_satisfied_alt_rounded,
                  color: colorScheme.tertiary, size: 16),
              const SizedBox(width: 6),
              Text(
                "Feeling",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline text showing "feels [emoji] [label]" in the post card header.
class FeelingDisplay extends StatelessWidget {
  final String userName;
  final Feeling feeling;

  const FeelingDisplay({
    super.key,
    required this.userName,
    required this.feeling,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: ' — is feeling ',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
          TextSpan(
            text: '${feeling.emoji} ${feeling.label}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
