import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/home/presentation/widgets/media_widgets.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/home/presentation/providers/posts_provider.dart';
 import 'package:project_test2/core/widgets/custom_confirm_dialog.dart';

class RepostsScreen extends StatefulWidget {
  const RepostsScreen({super.key});

  @override
  State<RepostsScreen> createState() => _RepostsScreenState();
}

class _RepostsScreenState extends State<RepostsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userId = context.select<AuthProvider, String?>((auth) => auth.userId);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        elevation: 0,
        title: const Text('Reposts', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: userId == null
          ? Center(child: Text('No reposts yet', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))))
          : Builder(
              builder: (context) {
                final all = context.watch<PostsProvider>().posts;
                final posts = all.where((p) => p.userId == userId && p.repostOf != null).toList();
                if (posts.isEmpty) {
                  return Center(
                    child: Text('No reposts yet', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  );
                }
                return ListView.builder(
                  itemCount: posts.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, i) {
                    final post = posts[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color ?? theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'من ${post.originalUserName ?? 'User'}',
                                    style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                  ),
                                ),
                                PopupMenuButton(
                                  icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: AppTheme.error),
                                          SizedBox(width: 8),
                                          Text('Delete repost'),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onSelected: (value) async {
                                    if (value != 'delete') return;
                                    await CustomConfirmDialog.show(
                                      context,
                                      title: 'Delete Repost',
                                      content: 'Are you sure you want to delete this repost?',
                                      confirmLabel: 'Delete',
                                      confirmColor: AppTheme.error,
                                      icon: Icons.delete_forever_rounded,
                                      onConfirm: () async {
                                        await context.read<PostsProvider>().deletePost(post.id, []);
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          if ((post.originalText ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(post.originalText!, style: TextStyle(color: theme.colorScheme.onSurface)),
                            ),
                          if (post.originalImageUrl != null)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullscreenImagesPage(urls: [post.originalImageUrl!]),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                child: CachedNetworkImage(imageUrl: post.originalImageUrl!, fit: BoxFit.cover, width: double.infinity),
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
