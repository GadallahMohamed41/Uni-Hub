import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/reactions.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../profile/user_profile_screen.dart';
import '../../profile/profile_screen.dart';
Future<void> showPostReactionsSheet(BuildContext context, PostModel post) async {
  final service = FirestoreService();

  final likedIds = post.likedBy;
  final laughedIds = post.laughedBy;
  final supportedIds = post.supportedBy;

  final entries = <({String uid, ReactionType type})>[
    ...likedIds.map((e) => (uid: e, type: ReactionType.like)),
    ...laughedIds.map((e) => (uid: e, type: ReactionType.laugh)),
    ...supportedIds.map((e) => (uid: e, type: ReactionType.support)),
  ];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      final height = MediaQuery.of(context).size.height * 0.65;
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final entry = entries[i];
                  return FutureBuilder<UserModel?>(
                    future: service.getUser(entry.uid),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      final name = user?.name ?? 'User';
                      final avatar = (user?.avatarUrl ?? '').trim();
                      final icon = ReactionUi.iconFor(entry.type);
                      final color = ReactionUi.colorFor(entry.type);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                          child: avatar.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: Icon(icon, color: color),
                        onTap: () {
                          final authProvider = context.read<AuthProvider>();
                          if (authProvider.userId == entry.uid) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: entry.uid),
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
