import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/utils/reactions.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/profile_screen.dart';
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

  // Pre-fetch all user profiles in parallel.
  // This resolves from memory cache instantly on subsequent loads.
  final loadUsersFuture = Future.wait(
    entries.map((entry) async {
      final user = await service.getUser(entry.uid);
      return (user: user, type: entry.type, uid: entry.uid);
    }),
  );

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
              child: FutureBuilder<List<({UserModel? user, ReactionType type, String uid})>>(
                future: loadUsersFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    // Premium skeleton loader matching the list items layout.
                    // This prevents layout shifts and gives a high-quality loading feel.
                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                            child: const SizedBox.shrink(),
                          ),
                          title: Container(
                            width: 120,
                            height: 16,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          trailing: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    );
                  }

                  final loadedEntries = snapshot.data ?? [];
                  if (loadedEntries.isEmpty) {
                    return Center(
                      child: Text(
                        'No reactions yet',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: loadedEntries.length,
                    itemBuilder: (context, i) {
                      final item = loadedEntries[i];
                      final user = item.user;
                      final name = user?.name ?? 'User';
                      final avatar = (user?.avatarUrl ?? '').trim();
                      final icon = ReactionUi.iconFor(item.type);
                      final color = ReactionUi.colorFor(item.type);
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
                          if (authProvider.userId == item.uid) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UserProfileScreen(userId: item.uid),
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
