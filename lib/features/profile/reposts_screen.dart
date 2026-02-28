import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/features/home/widgets/media_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';

class RepostsScreen extends StatefulWidget {
  const RepostsScreen({super.key});

  @override
  State<RepostsScreen> createState() => _RepostsScreenState();
}

class _RepostsScreenState extends State<RepostsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().listenToPosts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().userId;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        title: const Text('Reposts', style: TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w700)),
      ),
      body: Consumer<PostsProvider>(
        builder: (context, postsProvider, _) {
          final posts = postsProvider.posts.where((p) => p.userId == userId && p.repostOf != null).toList();
          if (posts.isEmpty) {
            return const Center(
              child: Text('No reposts yet', style: TextStyle(color: AppTheme.textSecondary)),
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
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
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
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                          PopupMenuButton(
                            icon: Icon(Icons.more_horiz, color: AppTheme.textTertiary),
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
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete repost'),
                                  content: const Text('Are you sure you want to delete this repost?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              await context.read<PostsProvider>().deletePost(post.id, post.imageUrls);
                            },
                          ),
                        ],
                      ),
                    ),
                    if ((post.originalText ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(post.originalText!, style: const TextStyle(color: AppTheme.textMain)),
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
                        child: CachedNetworkImage(imageUrl: post.originalImageUrl!, fit: BoxFit.cover),
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
