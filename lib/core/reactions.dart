import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';

enum ReactionType {
  like,
  support,
  laugh,
}

class ReactionUi {
  static IconData iconFor(ReactionType? type) {
    if (type == ReactionType.laugh) return Icons.emoji_emotions_rounded;
    if (type == ReactionType.support) return Icons.favorite_rounded;
    if (type == ReactionType.like) return Icons.thumb_up_rounded;
    return Icons.add_reaction_outlined;
  }

  static String labelFor(ReactionType? type) {
    if (type == ReactionType.laugh) return 'Haha';
    if (type == ReactionType.support) return 'Love';
    if (type == ReactionType.like) return 'Like';
    return 'React';
  }

  static Color colorFor(ReactionType? type) {
    if (type == ReactionType.laugh) return AppTheme.accent;
    if (type == ReactionType.support) return AppTheme.error;
    if (type == ReactionType.like) return AppTheme.primary;
    return AppTheme.textSecondary;
  }
}

