import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme.dart';
import '../../../core/reactions.dart';
import '../../../models/post_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_service.dart';

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
      final height = MediaQuery.of(context).size.height * 0.65;
      return Container(
        height: height,
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
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
                          backgroundImage: avatar.isNotEmpty ? CachedNetworkImageProvider(avatar) : null,
                          child: avatar.isEmpty ? const Icon(Icons.person) : null,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Icon(icon, color: color),
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
