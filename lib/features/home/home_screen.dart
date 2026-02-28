import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_test2/features/home/widgets/create_post_area.dart';
import 'package:project_test2/features/home/widgets/post_card.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/core/reactions.dart';
import 'package:project_test2/widgets/reaction_picker.dart';
import '../profile/notifications_screen.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../services/firestore_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  bool _searchMode = false;
  Widget _buildSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: "Search",
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary, size: 20),
            onPressed: () => setState(() {
              _searchMode = false;
              _searchQuery = '';
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }



  @override
  void initState() {
    super.initState();
    // بدء الاستماع للمنشورات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PostsProvider>().listenToPosts();
    });
  }

  void _showCreatePostSheet({List<Uint8List>? initialImages, Uint8List? initialVideo}) {
    String postText = "";
    List<Uint8List> selectedImagesBytes = initialImages ?? [];
    Uint8List? selectedVideoBytes = initialVideo;
    var previewIndex = 0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final postsProvider = context.watch<PostsProvider>();
            
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Create Post",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMain,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    maxLines: 6,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textMain,
                    ),
                    decoration: InputDecoration(
                      hintText: "What's on your mind?",
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      border: InputBorder.none,
                    ),
                    onChanged: (val) => postText = val,
                  ),
                  if (selectedImagesBytes.isNotEmpty)
                    Container(
                      height: 180,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 16),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: AppTheme.surfaceVariant,
                      ),
                      child: Stack(
                        children: [
                          PageView.builder(
                            itemCount: selectedImagesBytes.length,
                            onPageChanged: (i) => setSheetState(() => previewIndex = i),
                            itemBuilder: (context, i) {
                              return Image.memory(
                                selectedImagesBytes[i],
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              );
                            },
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.45),
                              ),
                              onPressed: () => setSheetState(() {
                                selectedImagesBytes = [];
                                previewIndex = 0;
                              }),
                            ),
                          ),
                          if (selectedImagesBytes.length > 1)
                            Positioned(
                              bottom: 10,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(selectedImagesBytes.length, (i) {
                                  final active = i == previewIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: active ? 12 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(active ? 0.95 : 0.55),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          if (selectedImagesBytes.length > 1)
                            Positioned(
                              top: 10,
                              left: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${previewIndex + 1}/${selectedImagesBytes.length}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  if (selectedVideoBytes != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.smart_display_rounded, color: AppTheme.warning),
                          SizedBox(width: 8),
                          Text('Video selected', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_rounded, color: AppTheme.info),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceVariant,
                        ),
                        onPressed: () async {
                          final images = await _picker.pickMultiImage();
                          if (images.isEmpty) return;
                          final bytesList = <Uint8List>[];
                          for (final img in images) {
                            bytesList.add(await img.readAsBytes());
                          }
                          setSheetState(() {
                            selectedImagesBytes = bytesList;
                            previewIndex = 0;
                            selectedVideoBytes = null;
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.smart_display_rounded, color: AppTheme.warning),
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.surfaceVariant,
                        ),
                        onPressed: () async {
                          final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                          if (video == null) return;
                          final bytes = await video.readAsBytes();
                          setSheetState(() {
                            selectedVideoBytes = bytes;
                            selectedImagesBytes = [];
                          });
                        },
                      ),
                      ElevatedButton(
                        onPressed: postsProvider.isCreatingPost
                            ? null
                            : () async {
                                if (postText.isNotEmpty || selectedImagesBytes.isNotEmpty || (selectedVideoBytes != null)) {
                                  final authProvider = context.read<AuthProvider>();
                                  final user = authProvider.currentUser;
                                  
                                  if (user != null) {
                                    final success = await postsProvider.createPost(
                                      userId: user.uid,
                                      userName: user.name,
                                      userBio: user.bio ?? 'Student',
                                      userAvatarUrl: user.avatarUrl,
                                      text: postText,
                                      imageBytesList: selectedImagesBytes,
                                      videoBytes: selectedVideoBytes,
                                      status: user.isAdmin ? 'approved' : 'pending',
                                    );
                                    
                                    if (!mounted) return;
                                    if (success) {
                                      Navigator.pop(context);
                                      if (!user.isAdmin) {
                                        AppSnackBar.showInfo(context, 'Post submitted for approval');
                                      }
                                    } else {
                                      final msg = postsProvider.error ?? 'Failed to create post';
                                      AppSnackBar.showError(context, msg);
                                    }
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        ),
                        child: postsProvider.isCreatingPost
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text("Post"),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCommentSheet(PostModel post) {
    final TextEditingController ctrl = TextEditingController();
    final ScrollController listCtrl = ScrollController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setCommentState) {
          final postsProvider = context.read<PostsProvider>();
          final authProvider = context.read<AuthProvider>();
          
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textTertiary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Comments",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    color: AppTheme.textMain,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<List<CommentModel>>(
                    stream: postsProvider.getCommentsStream(post.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Failed to load comments. Please try again.',
                              style: TextStyle(color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      
                      final comments = snapshot.data ?? [];
                      
                      if (comments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.comment_outlined,
                                size: 64,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No comments yet",
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Be the first to comment!",
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.builder(
                        controller: listCtrl,
                        itemCount: comments.length,
                        padding: const EdgeInsets.only(top: 8),
                        itemBuilder: (c, i) {
                          final comment = comments[i];
                          return _buildCommentThreadItem(comment, post, postsProvider, authProvider);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: TextStyle(color: AppTheme.textTertiary),
                          filled: true,
                          fillColor: AppTheme.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () async {
                          if (ctrl.text.isNotEmpty) {
                            final user = authProvider.currentUser;
                            if (user != null) {
                              await postsProvider.addComment(
                                postId: post.id,
                                userId: user.uid,
                                userName: user.name,
                                userAvatarUrl: user.avatarUrl,
                                text: ctrl.text,
                              );
                              ctrl.clear();
                              if (listCtrl.hasClients) {
                                listCtrl.jumpTo(listCtrl.position.maxScrollExtent);
                              }
                              setCommentState(() {});
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCommentThreadItem(
    CommentModel comment,
    PostModel post,
    PostsProvider postsProvider,
    AuthProvider authProvider,
  ) {
    return StreamBuilder<List<CommentModel>>(
      stream: postsProvider.getCommentRepliesStream(comment.id),
      builder: (context, repliesSnapshot) {
        final replies = repliesSnapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: comment.userAvatarUrl != null
                        ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                        : null,
                    child: comment.userAvatarUrl == null
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  comment.userName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMain,
                                  ),
                                ),
                              ),
                              Text(
                                comment.formattedTime,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            comment.text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textMain,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _showReplyDialog(comment, post, postsProvider, authProvider),
                                child: const Text('Reply', style: TextStyle(fontSize: 12)),
                              ),
                              if (comment.repliesCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text(
                                    '${comment.repliesCount} replies',
                                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (replies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 50, top: 8),
                  child: Column(
                    children: replies.map((reply) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: reply.userAvatarUrl != null
                                  ? CachedNetworkImageProvider(reply.userAvatarUrl!)
                                  : null,
                              child: reply.userAvatarUrl == null
                                  ? const Icon(Icons.person, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceVariant.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reply.userName,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textMain,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      reply.text,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textMain,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showReplyDialog(
    CommentModel comment,
    PostModel post,
    PostsProvider postsProvider,
    AuthProvider authProvider,
  ) {
    final replyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reply to ${comment.userName}'),
        content: TextField(
          controller: replyCtrl,
          decoration: InputDecoration(
            hintText: 'Write a reply...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(this.context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (replyCtrl.text.isNotEmpty) {
                final user = authProvider.currentUser;
                if (user != null) {
                  await postsProvider.addComment(
                    postId: post.id,
                    userId: user.uid,
                    userName: user.name,
                    userAvatarUrl: user.avatarUrl,
                    text: replyCtrl.text,
                    parentCommentId: comment.id,
                  );
                  if (!mounted) return;
                  Navigator.of(this.context).pop();
                }
              }
            },
            child: const Text('Reply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userId = authProvider.userId;
    final postsProvider = context.watch<PostsProvider>();
    final filteredPosts = _searchQuery.isEmpty
        ? postsProvider.posts
        : postsProvider.posts.where((p) {
            final q = _searchQuery.toLowerCase();
            return p.text.toLowerCase().contains(q) ||
                p.userName.toLowerCase().contains(q) ||
                p.userBio.toLowerCase().contains(q);
          }).toList();
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            pinned: true,
            floating: true,
            title: _searchMode
                ? _buildSearchBar()
                : const Text(
                    "University Feed",
                    style: TextStyle(
                      color: AppTheme.textMain,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                  ),
            actions: _searchMode
                ? []
                : [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: StreamBuilder<int>(
                        stream: userId == null
                            ? Stream<int>.empty()
                            : FirestoreService().getUnreadNotificationsCountStream(userId),
                        builder: (context, snapshot) {
                          final count = snapshot.data ?? 0;
                          final text = count > 99 ? '99+' : '$count';
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                onPressed: userId == null
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                        );
                                      },
                                icon: const Icon(Icons.notifications_none_rounded, color: AppTheme.textMain),
                                iconSize: 22,
                              ),
                              if (count > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.error,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: AppTheme.surfaceVariant, width: 2),
                                    ),
                                    child: Text(
                                      text,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => setState(() => _searchMode = true),
                        icon: const Icon(Icons.search_rounded, color: AppTheme.textMain),
                        iconSize: 22,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
          ),

          

          //  بدء منشور
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: CreatePostArea(
                onTapComposer: _showCreatePostSheet,
                onTapPhoto: _showCreatePostSheet,
                onTapVideo: () async {
                  final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
                  if (video == null) return;
                  final bytes = await video.readAsBytes();
                  if (!mounted) return;
                  _showCreatePostSheet(initialVideo: bytes);
                },
              ),
            ),
          ),

          // قائمة المنشورات
          Consumer<PostsProvider>(
            builder: (context, _, __) {
              if (filteredPosts.isEmpty) {
                return const SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.post_add_rounded,
                          size: 64,
                          color: AppTheme.textTertiary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No posts yet",
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Be the first to share something!",
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(
                      top: index == 0 ? 8 : 0,
                      bottom: 12,
                    ),
                    child: PostCard(
                      post: filteredPosts[index],
                      onShowComment: (p) => _showCommentSheet(p),
                      onShowRepost: (p) => _showRepostSheet(p),
                      onShowReactionPicker: (p) => _showReactionPicker(p),
                    ),
                  ),
                  childCount: filteredPosts.length,
                  addSemanticIndexes: false,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  

  
  
  void _showReactionPicker(PostModel post) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;
    showReactionPickerDialog(
      context: context,
      onSelect: (type) {
        final postsProvider = context.read<PostsProvider>();
        if (type == ReactionType.like) postsProvider.toggleLike(post.id, userId);
        if (type == ReactionType.laugh) postsProvider.toggleLaugh(post.id, userId);
        if (type == ReactionType.support) postsProvider.toggleSupport(post.id, userId);
      },
    );
  }

  void _showRepostSheet(PostModel post) {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;
    String caption = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                left: 20,
                right: 20,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.textTertiary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Add caption to repost",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textMain),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: "Write a caption...",
                      
                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (v) => caption = v.trim(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await context.read<PostsProvider>().createRepost(
                          userId: user.uid,
                          userName: user.name,
                          userBio: user.bio ?? 'Student',
                          userAvatarUrl: user.avatarUrl,
                          originalPostId: post.id,
                          text: caption,
                        );
                        if (!mounted) return;
                        Navigator.pop(context);
                        if (ok) {
                          AppSnackBar.showSuccess(context, 'Reposted');
                        } else {
                          AppSnackBar.showError(context, 'Failed to repost');
                        }
                      },
                      child: const Text("Repost"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  

  
}

 
