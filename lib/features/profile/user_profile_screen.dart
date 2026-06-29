import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/features/home/widgets/post_card.dart';
import 'package:project_test2/features/profile/CertificatesViewerScreen.dart';
import 'cv_viewer_screen.dart';
import 'fullscreen_image_viewer.dart';
import 'package:project_test2/providers/posts_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../core/animations.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../models/comment_model.dart';
import '../home/widgets/comments_sheet.dart';
import '../../core/reactions.dart';
import '../../widgets/reaction_picker.dart';
import '../../widgets/custom_confirm_dialog.dart';
import '../../widgets/image_detail_screen.dart';
import '../connections/data/connections_repository.dart';
import '../chat/data/repositories/chat_repository_impl.dart';
import '../chat/presentation/screens/direct_message_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ConnectionsRepository _connectionsRepository =
      ConnectionsRepository(FirebaseFirestore.instance);
  UserModel? _user;
  bool _isLoading = true;

  List<Map<String, dynamic>> _certificates = [];

  ConnectionStatus? _connectionStatus;
  bool _isLoadingRelations = true;
  bool _relationsInitialized = false;
  bool _isConnectionActionLoading = false;

  // Follow System Variables
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadFollowData();
  }

  Future<void> _loadFollowData() async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) return;
    if (currentUserId == widget.userId) return;

    _isFollowing =
        await _firestoreService.isFollowing(currentUserId, widget.userId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFollowUser() async {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?.uid;
    if (currentUserId == null) return;
    if (currentUserId == widget.userId) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        final success =
            await _firestoreService.unfollowUser(currentUserId, widget.userId);
        if (success) {
          setState(() => _isFollowing = false);
        }
      } else {
        final success =
            await _firestoreService.followUser(currentUserId, widget.userId);
        if (success) {
          setState(() => _isFollowing = true);
        }
      }
    } catch (e) {
      // silent
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Future<void> _loadUser() async {
    try {
      final user = await _firestoreService.getUser(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }

      if (user != null) {
        await _checkCertificates();
      }
    } catch (e) {
      debugPrint(' Error loading user: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkCertificates() async {
    try {
      final certs = await _firestoreService.listUserCertificates(
        userId: widget.userId,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _certificates = certs;
        });
      }
    } catch (e) {
      debugPrint('Error checking certificates: $e');
    }
  }

  void _showBlockOptions(BuildContext context, UserModel user) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Admin Actions",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 20),
            if (user.isBlocked)
              _buildActionTile(
                context,
                icon: Icons.lock_open_rounded,
                title: "Unblock User",
                color: AppTheme.success,
                onTap: () async {
                  await _firestoreService.unblockUser(user.uid);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadUser();
                    AppSnackBar.showSuccess(
                        context, "User unblocked successfully");
                  }
                },
              )
            else ...[
              _buildActionTile(
                context,
                icon: Icons.timer_outlined,
                title: "Block for 2 Days",
                color: Colors.orange,
                onTap: () async {
                  await _firestoreService.blockUser(
                    userId: user.uid,
                    until: DateTime.now().add(const Duration(days: 2)),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadUser();
                    AppSnackBar.showSuccess(context, "User blocked for 2 days");
                  }
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.calendar_today_outlined,
                title: "Block for 1 Week",
                color: Colors.deepOrange,
                onTap: () async {
                  await _firestoreService.blockUser(
                    userId: user.uid,
                    until: DateTime.now().add(const Duration(days: 7)),
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadUser();
                    AppSnackBar.showSuccess(context, "User blocked for 1 week");
                  }
                },
              ),
              _buildActionTile(
                context,
                icon: Icons.block_flipped,
                title: "Block Forever",
                color: AppTheme.error,
                onTap: () async {
                  await _firestoreService.blockUser(userId: user.uid);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadUser();
                    AppSnackBar.showSuccess(context, "User blocked forever");
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 14, color: color)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _openlLink(String link) async {
    final trimmed = link.trim();
    if (trimmed.isEmpty) {
      AppSnackBar.showError(context, 'Link is empty');
      return;
    }
    final finalLink = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    final url = Uri.tryParse(finalLink);
    if (url == null || !url.hasScheme) {
      AppSnackBar.showError(context, 'Invalid link');
      return;
    }
    try {
      final canLaunch = await canLaunchUrl(url);
      if (canLaunch) {
        await launchUrl(
          url,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
          webOnlyWindowName: '_blank',
        );
      } else {
        if (mounted) AppSnackBar.showError(context, 'Cannot open link');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Failed to open link');
    }
  }

  // ignore: unused_element
  void _showCommentSheet(PostModel post) {
    final TextEditingController ctrl = TextEditingController();
    final ScrollController listCtrl = ScrollController();

    final postsProvider = context.read<PostsProvider>();
    final commentsStream = postsProvider.getCommentsStream(post.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setCommentState) {
          final authProvider = context.read<AuthProvider>();
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Comments",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.1)),
                Expanded(
                  child: StreamBuilder<List<CommentModel>>(
                    stream: commentsStream,
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
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6)),
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
                              Icon(Icons.comment_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.2)),
                              const SizedBox(height: 16),
                              Text("No comments yet",
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                      fontSize: 16)),
                              const SizedBox(height: 8),
                              Text("Be the first to comment!",
                                  style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                      fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: listCtrl,
                        itemCount: comments.length,
                        padding: const EdgeInsets.only(top: 8),
                        itemBuilder: (c, i) => _buildCommentThreadItem(
                            comments[i], post, postsProvider, authProvider),
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
                        style: TextStyle(
                            color: theme.colorScheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Write a comment...",
                          hintStyle: TextStyle(
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 14),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppTheme.surfaceVariant,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: const BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded,
                            color: Colors.white, size: 18),
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
                                listCtrl
                                    .jumpTo(listCtrl.position.maxScrollExtent);
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

  void _ensureRelationsLoaded(UserModel profileUser, UserModel currentUser) {
    if (_relationsInitialized) {
      return;
    }
    _relationsInitialized = true;
    _isLoadingRelations = true;
    _loadRelations(profileUser, currentUser);
  }

  Future<void> _loadRelations(
      UserModel profileUser, UserModel currentUser) async {
    try {
      final status = await _connectionsRepository.getConnectionStatus(
        currentUserId: currentUser.uid,
        otherUserId: profileUser.uid,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = status;
        _isLoadingRelations = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingRelations = false;
      });
    }
  }

  Future<void> _handleConnect(
      UserModel currentUser, UserModel profileUser) async {
    if (_isConnectionActionLoading) {
      return;
    }
    setState(() {
      _isConnectionActionLoading = true;
    });
    try {
      await _connectionsRepository.sendConnectionRequest(
        fromUserId: currentUser.uid,
        toUserId: profileUser.uid,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = ConnectionStatus.pending;
        _isConnectionActionLoading = false;
      });
    } catch (e, st) {
      debugPrint('  Error in _handleConnect: $e\n$st');
      if (!mounted) return;
      AppSnackBar.showError(context, 'Could not send request: $e');
      setState(() {
        _isConnectionActionLoading = false;
      });
    }
  }

  Future<void> _handleAccept(
      UserModel currentUser, UserModel profileUser) async {
    if (_isConnectionActionLoading) {
      return;
    }
    setState(() {
      _isConnectionActionLoading = true;
    });
    try {
      await _connectionsRepository.acceptConnectionRequest(
        currentUserId: currentUser.uid,
        fromUserId: profileUser.uid,
      );
      await _loadUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = ConnectionStatus.connected;
        _isConnectionActionLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnectionActionLoading = false;
      });
      AppSnackBar.showError(context, 'Failed to accept connection.');
    }
  }

  // ignore: unused_element
  Future<void> _handleIgnore(
      UserModel currentUser, UserModel profileUser) async {
    if (_isConnectionActionLoading) {
      return;
    }
    setState(() {
      _isConnectionActionLoading = true;
    });
    try {
      await _connectionsRepository.ignoreConnectionRequest(
        currentUserId: currentUser.uid,
        fromUserId: profileUser.uid,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = ConnectionStatus.connectable;
        _isConnectionActionLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnectionActionLoading = false;
      });
      AppSnackBar.showError(context, 'Failed to ignore connection.');
    }
  }

  Future<void> _handleDisconnect(
      UserModel currentUser, UserModel profileUser) async {
    await CustomConfirmDialog.show(
      context,
      title: 'Disconnect',
      content: 'Are you sure you want to remove this connection?',
      confirmLabel: 'Disconnect',
      confirmColor: AppTheme.error,
      icon: Icons.person_remove_rounded,
      onConfirm: () async {
        if (_isConnectionActionLoading) return;

        setState(() {
          _isConnectionActionLoading = true;
        });

        await _connectionsRepository.removeConnection(
          currentUserId: currentUser.uid,
          otherUserId: profileUser.uid,
        );

        await _loadUser();

        if (!mounted) return;
        setState(() {
          _connectionStatus = ConnectionStatus.connectable;
          _isConnectionActionLoading = false;
        });
      },
    );
  }

  Widget _buildCommentThreadItem(
    CommentModel comment,
    PostModel post,
    PostsProvider postsProvider,
    AuthProvider authProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                  GestureDetector(
                    onTap: () {
                      if (comment.userId != widget.userId) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                UserProfileScreen(userId: comment.userId),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage: comment.userAvatarUrl != null
                          ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                          : null,
                      child: comment.userAvatarUrl == null
                          ? const Icon(Icons.person, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(comment.userName,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface)),
                              ),
                              Text(comment.formattedTime,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4))),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(comment.text,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurface,
                                  height: 1.3)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => _showReplyDialog(
                                    comment, post, postsProvider, authProvider),
                                child: const Text('Reply',
                                    style: TextStyle(fontSize: 11)),
                              ),
                              if (comment.repliesCount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(left: 6),
                                  child: Text('${comment.repliesCount} replies',
                                      style: TextStyle(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
                                          fontSize: 11)),
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
                            GestureDetector(
                              onTap: () {
                                if (reply.userId != widget.userId) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => UserProfileScreen(
                                          userId: reply.userId),
                                    ),
                                  );
                                }
                              },
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: reply.userAvatarUrl != null
                                    ? CachedNetworkImageProvider(
                                        reply.userAvatarUrl!)
                                    : null,
                                child: reply.userAvatarUrl == null
                                    ? const Icon(Icons.person, size: 14)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.03)
                                      : AppTheme.surfaceVariant
                                          .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(reply.userName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                theme.colorScheme.onSurface)),
                                    const SizedBox(height: 1),
                                    Text(reply.text,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.onSurface,
                                            height: 1.2)),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: comment.userAvatarUrl != null
                          ? CachedNetworkImageProvider(
                              comment.userAvatarUrl!,
                            )
                          : null,
                      child: comment.userAvatarUrl == null
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment.userName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            comment.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: replyCtrl,
                  maxLines: 3,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppTheme.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (replyCtrl.text.trim().isEmpty) return;
                      final user = authProvider.currentUser;
                      if (user == null) return;
                      await postsProvider.addComment(
                        postId: post.id,
                        userId: user.uid,
                        userName: user.name,
                        userAvatarUrl: user.avatarUrl,
                        text: replyCtrl.text.trim(),
                        parentCommentId: comment.id,
                      );
                      if (!mounted) return;
                      Navigator.of(this.context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Reply',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showReactionPicker(PostModel post, Offset globalPosition) {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.userId;
    if (userId == null) return;
    showReactionPickerPopover(
      context: context,
      globalPosition: globalPosition,
      onSelect: (type) {
        final postsProvider = context.read<PostsProvider>();
        if (type == ReactionType.like) {
          postsProvider.toggleLike(post.id, userId);
        }
        if (type == ReactionType.laugh) {
          postsProvider.toggleLaugh(post.id, userId);
        }
        if (type == ReactionType.support) {
          postsProvider.toggleSupport(post.id, userId);
        }
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
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            final postsProvider = context.watch<PostsProvider>();
            return Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color ?? theme.colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                left: 16,
                right: 16,
                top: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text("Repost",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (v) => caption = v,
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: "Add a caption...",
                      hintStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 14),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.03)
                          : AppTheme.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        if (post.imageUrls.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                                imageUrl: post.imageUrls.first,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover),
                          )
                        else
                          CircleAvatar(
                            radius: 20,
                            backgroundImage: post.userAvatarUrl != null
                                ? CachedNetworkImageProvider(
                                    post.userAvatarUrl!)
                                : null,
                            child: post.userAvatarUrl == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post.userName,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface)),
                              Text(
                                post.text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: postsProvider.isCreatingPost
                          ? null
                          : () async {
                              if (user.isBlocked) {
                                if (user.blockedUntil != null &&
                                    user.blockedUntil!
                                        .isAfter(DateTime.now())) {
                                  AppSnackBar.showError(context,
                                      'You are blocked from reposting until ${user.blockedUntil.toString().split('.')[0]}');
                                  return;
                                } else if (user.blockedUntil == null) {
                                  AppSnackBar.showError(context,
                                      'You are permanently blocked from reposting');
                                  return;
                                }
                              }
                              final ok = await context
                                  .read<PostsProvider>()
                                  .createRepost(
                                    userId: user.uid,
                                    userName: user.name,
                                    userBio: user.bio ?? 'Student',
                                    userAvatarUrl: user.avatarUrl,
                                    originalPostId: post.id,
                                    text: caption,
                                  );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              if (ok) {
                                AppSnackBar.showSuccess(
                                    context, "Reposted successfully");
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: postsProvider.isCreatingPost
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text("Repost Now",
                              style: TextStyle(fontSize: 14)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('User not found')),
        body: const Center(child: Text('User not found')),
      );
    }

    final user = _user!;
    final avatarUrl = (user.avatarUrl ?? '').trim();
    final hasAvatarUrl = avatarUrl.isNotEmpty;
    final cvUrl = (user.cvUrl ?? '').trim();
    final hasCvUrl = cvUrl.isNotEmpty;

    final currentUser = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final isAdmin = currentUser?.role == 'admin';
    final isOwnProfile = currentUser?.uid == widget.userId;

    if (currentUser == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Text(
            'Sign in to view profiles',
            style:
                TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ),
      );
    }

    if (!isOwnProfile) {
      _ensureRelationsLoaded(user, currentUser);
    }

    String connectLabel = 'Connect';
    VoidCallback? connectOnPressed;

    if (!isOwnProfile) {
      if (_isLoadingRelations || _isConnectionActionLoading) {
        connectLabel = 'Loading...';
        connectOnPressed = null;
      } else {
        final status = _connectionStatus;
        if (status == ConnectionStatus.connected) {
          connectLabel = 'Connected';
          if (!_isConnectionActionLoading) {
            connectOnPressed = () {
              _showConnectionOptions(currentUser, user);
            };
          }
        } else if (status == ConnectionStatus.pending) {
          connectLabel = 'Pending';
          connectOnPressed = null;
        } else if (status == ConnectionStatus.incomingRequest) {
          connectLabel = 'Accept';
          if (!_isConnectionActionLoading) {
            connectOnPressed = () {
              _handleAccept(currentUser, user);
            };
          }
        } else {
          connectLabel = 'Connect';
          if (!_isConnectionActionLoading) {
            connectOnPressed = () {
              _handleConnect(currentUser, user);
            };
          }
        }
      }
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // 1. Cover Section
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: (_user?.coverUrl ?? '').isNotEmpty
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenImageViewer(
                                    imageProvider: CachedNetworkImageProvider(
                                        _user!.coverUrl!),
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: Container(
                        height: 240,
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: ClipPath(
                          clipper: const _CoverCustomClipper(),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Background Gradient
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? [const Color(0xFF07112B), const Color(0xFF0F2040)]
                                        : [AppTheme.primary, AppTheme.primaryDark],
                                  ),
                                ),
                              ),
                              if ((_user?.coverUrl ?? '').isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: _user!.coverUrl!,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  placeholder: (context, url) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.modernCoverGradient,
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: AppTheme.modernCoverGradient,
                                    ),
                                    child: const Icon(
                                      Icons.error_outline_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              // Dark overlay on cover image
                              if ((_user?.coverUrl ?? '').isNotEmpty)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              // Custom Painter for decorative elements (only if NO cover image is present)
                              if ((_user?.coverUrl ?? '').isEmpty)
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: _CoverDecorationsPainter(),
                                  ),
                                ),
                              // Thin cyan-to-blue gradient top bar
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF00FFFF), Color(0xFF0000FF)],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 2. Info Card Section
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 200),
                      FadeInAnimation(
                        delay: 200,
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          padding: const EdgeInsets.fromLTRB(24, 64, 24, 20),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ?? theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                user.name,
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                    letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 6),
                              // Gradient Underline
                              Container(
                                width: 50,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1.5),
                                  gradient: const LinearGradient(
                                    colors: [Colors.cyan, Colors.blue],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (user.studentId != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1D2840) : Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    user.bio?.trim().isNotEmpty == true
                                        ? user.bio!
                                        : "Student",
                                    textAlign: TextAlign.center,
                                    textWidthBasis: TextWidthBasis.longestLine,
                                    style: TextStyle(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 3. Avatar Section
                  Positioned(
                    top: 154,
                    child: FadeInAnimation(
                      delay: 100,
                      child: GestureDetector(
                        onTap: () {
                          if (avatarUrl.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ImageDetailScreen(
                                  imageUrl: avatarUrl,
                                  heroTag: 'profile_avatar_$avatarUrl',
                                ),
                              ),
                            );
                          }
                        },
                        child: Hero(
                          tag: 'profile_avatar_$avatarUrl',
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: theme.scaffoldBackgroundColor, width: 4),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8)),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 53,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppTheme.surfaceVariant,
                              backgroundImage: hasAvatarUrl
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: !hasAvatarUrl
                                  ? Icon(Icons.person,
                                      size: 53,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4))
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 4. Overlay Back Button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    left: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                  // 5. Overlay More/Admin Button
                  if (isAdmin && !isOwnProfile)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 12,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                          ),
                          onPressed: () => _showBlockOptions(context, user),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (!isOwnProfile)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    // زر Connect المعدل
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: connectOnPressed != null
                              ? const LinearGradient(
                                  colors: [
                                    AppTheme.primary,
                                    AppTheme.primaryDark
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: connectOnPressed != null
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: connectOnPressed,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: _isConnectionActionLoading
                                    ? SizedBox(
                                        key: const ValueKey('loading'),
                                        height: 20,
                                        width: 20,
                                        child: const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            connectLabel == 'Connected'
                                                ? Icons.check_circle_rounded
                                                : connectLabel == 'Pending'
                                                    ? Icons
                                                        .hourglass_empty_rounded
                                                    : connectLabel == 'Accept'
                                                        ? Icons
                                                            .person_add_rounded
                                                        : Icons
                                                            .person_add_alt_1_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            connectLabel,
                                            key: ValueKey(connectLabel),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    if (_connectionStatus == ConnectionStatus.connected) ...[
                      const SizedBox(width: 12),

                      // زر Message المعدل
                      Expanded(
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color ??
                                theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _isConnectionActionLoading
                                  ? null
                                  : () => _handleMessage(currentUser, user),
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      color: AppTheme.primary,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Message',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Builder(builder: (context) {
              final hasGithub = (user.githubLink ?? '').trim().isNotEmpty;
              final hasLinkedin = (user.linkedinLink ?? '').trim().isNotEmpty;
              final hasAnySocial = hasGithub || hasLinkedin;
              if (!hasAnySocial) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FadeInAnimation(
                  delay: 300,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color ?? theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasGithub)
                          Material(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _openlLink(user.githubLink!),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: SvgPicture.asset(
                                  'lib/assets/icons/gethub.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: const ColorFilter.mode(
                                      Colors.white, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        if (hasGithub && hasLinkedin) const SizedBox(width: 16),
                        if (hasLinkedin)
                          InkWell(
                            onTap: () => _openlLink(user.linkedinLink!),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0A66C2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SvgPicture.asset(
                                'lib/assets/icons/linkedin.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                    Colors.white, BlendMode.srcIn),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: FadeInAnimation(
                delay: 360,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColoredBox(
                            color: Colors.white,
                            child: Image.asset(
                              'lib/assets/icons/cv.jpeg',
                              width: 31,
                              height: 32,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.image_not_supported_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CV',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'عرض السيرة الذاتية',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: hasCvUrl
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CvViewerScreen(url: cvUrl),
                                  ),
                                )
                            : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          hasCvUrl ? 'عرض' : 'غير متاح',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: FadeInAnimation(
                delay: 360,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.cardTheme.color ?? theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppTheme.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Certificates',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'عرض الشهادات المرفوعة',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _certificates.isNotEmpty
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CertificatesViewerScreen(
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _certificates.isNotEmpty ? 'عرض' : 'غير متاح',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: FadeInAnimation(
                delay: 400,
                child: Consumer<PostsProvider>(
                  builder: (context, postsProvider, _) {
                    final theme = Theme.of(context);
                    final isDark = theme.brightness == Brightness.dark;
                    final userPosts = postsProvider.posts
                        .where((p) => p.userId == widget.userId)
                        .toList();
                    final count = userPosts.length;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Posts",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (count > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (!isOwnProfile)
                              GestureDetector(
                                onTap:
                                    _isFollowLoading ? null : _toggleFollowUser,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isFollowing
                                        ? Colors.green.shade400
                                        : AppTheme.primary,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: _isFollowing
                                        ? []
                                        : [
                                            BoxShadow(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _isFollowing ? "following" : "follow +",
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      if (_isFollowing) ...[
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_user != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Connections: ${_user!.connectionsCount}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        const SizedBox(height: 15),
                        if (userPosts.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.03)
                                  : AppTheme.surfaceVariant.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              "No posts yet",
                              style: TextStyle(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          )
                        else
                          Transform.translate(
                            offset: const Offset(0, -10),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: userPosts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final post = userPosts[index];
                                return PostCard(
                                  post: post,
                                  onShowComment: (p) =>
                                      showCommentsSheet(context, p),
                                  onShowRepost: (p) => _showRepostSheet(p),
                                  onShowReactionPicker: (p, pos) =>
                                      _showReactionPicker(p, pos),
                                  currentProfileUserId: widget.userId,
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _CoverCustomClipper extends CustomClipper<Path> {
  const _CoverCustomClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final sx = w / 380.0;
    final sy = h / 240.0;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(0, 200 * sy);
    path.cubicTo(0, 200 * sy, 40 * sx, 240 * sy, 70 * sx, 240 * sy);
    path.cubicTo(90 * sx, 240 * sy, 130 * sx, 228 * sy, 190 * sx, 210 * sy);
    path.cubicTo(250 * sx, 228 * sy, 290 * sx, 240 * sy, 310 * sx, 240 * sy);
    path.cubicTo(340 * sx, 240 * sy, 380 * sx, 200 * sy, 380 * sx, 200 * sy);
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _CoverDecorationsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Concentric circles on top-right and bottom-left
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    // Top-right circles
    final trCenter = Offset(size.width, 0);
    canvas.drawCircle(trCenter, 40, circlePaint);
    canvas.drawCircle(trCenter, 80, circlePaint);
    canvas.drawCircle(trCenter, 120, circlePaint);
    canvas.drawCircle(trCenter, 160, circlePaint);

    // Bottom-left circles
    final blCenter = Offset(0, size.height);
    canvas.drawCircle(blCenter, 50, circlePaint);
    canvas.drawCircle(blCenter, 100, circlePaint);
    canvas.drawCircle(blCenter, 150, circlePaint);
    canvas.drawCircle(blCenter, 200, circlePaint);

    // 2. Small dot grid pattern on top-left and top-right corners
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.cyan.withValues(alpha: 0.12);

    // Top-left dot grid (6x4 grid)
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 4; j++) {
        canvas.drawCircle(Offset(20.0 + i * 12.0, 20.0 + j * 12.0), 1.5, dotPaint);
      }
    }

    // Top-right dot grid (6x4 grid)
    for (int i = 0; i < 6; i++) {
      for (int j = 0; j < 4; j++) {
        canvas.drawCircle(Offset(size.width - 80.0 + i * 12.0, 20.0 + j * 12.0), 1.5, dotPaint);
      }
    }

    // 3. Two diagonal lines crossing symmetrically
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.blue.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    canvas.drawLine(const Offset(0, 40), Offset(size.width, size.height - 40), linePaint);
    canvas.drawLine(Offset(size.width, 40), Offset(0, size.height - 40), linePaint);

    // 4. Two hexagon outlines on left and right sides
    final hexPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.cyan.withValues(alpha: 0.08)
      ..strokeWidth = 1.2;

    _drawHexagon(canvas, Offset(45, size.height * 0.45), 25, hexPaint);
    _drawHexagon(canvas, Offset(size.width - 45, size.height * 0.45), 25, hexPaint);

    // 5. Small scattered particles (tiny circles)
    final particlePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.12);

    final particles = [
      Offset(size.width * 0.25, size.height * 0.25),
      Offset(size.width * 0.38, size.height * 0.15),
      Offset(size.width * 0.55, size.height * 0.35),
      Offset(size.width * 0.72, size.height * 0.22),
      Offset(size.width * 0.15, size.height * 0.65),
      Offset(size.width * 0.85, size.height * 0.60),
    ];

    for (var pt in particles) {
      canvas.drawCircle(pt, 2.0, particlePaint);
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = i * pi / 3;
      double x = center.dx + radius * cos(angle);
      double y = center.dy + radius * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

extension on _UserProfileScreenState {
  Future<void> _handleMessage(
      UserModel currentUser, UserModel profileUser) async {
    try {
      final repo = ChatRepositoryImpl();
      final conv = await repo.getOrCreateConversation(
        myId: currentUser.uid,
        myName: currentUser.name,
        myAvatar: currentUser.avatarUrl,
        otherId: profileUser.uid,
        otherName: profileUser.name,
        otherAvatar: profileUser.avatarUrl,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DirectMessageScreen(
            conversationId: conv.id,
            otherUserId: profileUser.uid,
            otherUserName: profileUser.name,
            otherUserAvatar: profileUser.avatarUrl,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('  _handleMessage error: $e\n$st');
      if (!mounted) return;
      AppSnackBar.showError(context, 'Could not open chat. Try again.');
    }
  }

  void _showConnectionOptions(UserModel currentUser, UserModel profileUser) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardTheme.color ?? theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              ListTile(
                leading:
                    const Icon(Icons.message_outlined, color: AppTheme.primary),
                title: const Text('Message',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _handleMessage(currentUser, profileUser);
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined,
                    color: AppTheme.error),
                title: const Text('Remove Connection',
                    style: TextStyle(
                        color: AppTheme.error, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _handleDisconnect(currentUser, profileUser);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
