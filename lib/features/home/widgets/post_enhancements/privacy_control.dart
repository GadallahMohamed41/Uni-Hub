/// Privacy Control Widget for the Create Post screen.
///
/// Provides three privacy options: Public, Friends Only, Private.
/// Displayed as toggle buttons below the text field.
library;

import 'package:flutter/material.dart';

/// Enum representing the privacy levels for a post.
enum PostPrivacy {
  public,
  friendsOnly,
  private_,
}

/// Returns the icon for the given privacy level.
IconData privacyIcon(PostPrivacy privacy) {
  switch (privacy) {
    case PostPrivacy.public:
      return Icons.public_rounded;
    case PostPrivacy.friendsOnly:
      return Icons.people_rounded;
    case PostPrivacy.private_:
      return Icons.lock_rounded;
  }
}

/// Returns the label for the given privacy level.
String privacyLabel(PostPrivacy privacy) {
  switch (privacy) {
    case PostPrivacy.public:
      return 'Public';
    case PostPrivacy.friendsOnly:
      return 'Friends Only';
    case PostPrivacy.private_:
      return 'Only Me';
  }
}

/// Returns the Firestore value for the given privacy level.
String privacyToFirestore(PostPrivacy privacy) {
  switch (privacy) {
    case PostPrivacy.public:
      return 'public';
    case PostPrivacy.friendsOnly:
      return 'friends_only';
    case PostPrivacy.private_:
      return 'private';
  }
}

/// Parses a Firestore value into a PostPrivacy enum.
PostPrivacy privacyFromFirestore(String? value) {
  switch (value) {
    case 'friends_only':
      return PostPrivacy.friendsOnly;
    case 'private':
      return PostPrivacy.private_;
    default:
      return PostPrivacy.public;
  }
}

/// A row of three toggle buttons for selecting post privacy.
class PrivacySelector extends StatelessWidget {
  final PostPrivacy selected;
  final ValueChanged<PostPrivacy> onChanged;

  const PrivacySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: PostPrivacy.values.map((privacy) {
        final isSelected = selected == privacy;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: privacy != PostPrivacy.private_ ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(privacy),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary.withValues(alpha: 0.5)
                        : colorScheme.outline.withValues(alpha: 0.15),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      privacyIcon(privacy),
                      size: 16,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        privacyLabel(privacy),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Small inline badge showing the privacy icon on a post card.
class PrivacyBadge extends StatelessWidget {
  final PostPrivacy privacy;

  const PrivacyBadge({super.key, required this.privacy});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: privacyLabel(privacy),
      child: Icon(
        privacyIcon(privacy),
        size: 12,
        color: colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}
