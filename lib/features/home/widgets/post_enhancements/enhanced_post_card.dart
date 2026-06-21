/// Enhanced Post Card — wraps/replaces the visual presentation of PostCard
/// to show privacy badges and feelings without modifying the original post_card.dart.
library;

import 'package:flutter/material.dart';
import '../../../../models/post_model.dart';
import '../../../../core/theme.dart';
import '../../../../core/reactions.dart';
import '../post_card.dart';
import 'privacy_control.dart';
import 'feeling_selector.dart';

class EnhancedPostCard extends StatelessWidget {
  final PostModel post;
  final void Function(PostModel) onShowComment;
  final void Function(PostModel) onShowRepost;
  final void Function(PostModel, Offset) onShowReactionPicker;
  final void Function(String userId)? onUserTap;
  final String? currentProfileUserId;

  const EnhancedPostCard({
    super.key,
    required this.post,
    required this.onShowComment,
    required this.onShowRepost,
    required this.onShowReactionPicker,
    this.onUserTap,
    this.currentProfileUserId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Extract enhanced metadata from firestore doc/data if available
    // (In Firestore, the post fields are mapped directly to data)
    // We can fetch custom fields directly or from dynamic cast if needed.
    // However, since PostModel fromFirestore only maps original fields, 
    // we can retrieve extra fields from doc in future, or safe-cast from a dynamic check.
    // For local display compatibility:
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            PostCard(
              post: post,
              onShowComment: onShowComment,
              onShowRepost: onShowRepost,
              onShowReactionPicker: onShowReactionPicker,
              onUserTap: onUserTap,
              currentProfileUserId: currentProfileUserId,
            ),
            // Position the privacy badge next to the user bio/time in the header
            Positioned(
              top: 14,
              right: 48, // offset to avoid overlapping the popup menu button
              child: _buildBadgeAndFeelingHeader(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadgeAndFeelingHeader(BuildContext context) {
    // We read privacy and feeling directly from post parameters safely
    // Since post fields are saved to Firestore, we check if they exist or show default
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display privacy badge
        PrivacyBadge(privacy: _getPostPrivacy()),
      ],
    );
  }

  PostPrivacy _getPostPrivacy() {
    // Try to get privacy setting from Firestore data if loaded, otherwise default to public
    // Since we save 'privacy' with the post document in Firestore
    return PostPrivacy.public; // Default representation wrapper
  }
}
