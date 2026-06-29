import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
  import 'package:project_test2/core/utils/animations.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/core/services/firestore_service.dart';
 import 'package:project_test2/features/profile/presentation/screens/user_profile_screen.dart';

class FollowersScreen extends StatefulWidget {
  final String userId;
  final String title;

  const FollowersScreen({
    super.key,
    required this.userId,
    this.title = 'Followers',
  });

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<UserModel> _followers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowers();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoading = true);
    try {
      final followers = await _firestoreService.getFollowersList(widget.userId);
      setState(() {
        _followers = followers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _followers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 80,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No followers yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'When someone follows you, they\'ll appear here',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _followers.length,
                  itemBuilder: (context, index) {
                    final user = _followers[index];
                    return FadeInAnimation(
                      delay: index * 50,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: theme.cardTheme.color ?? theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          onTap: () => _navigateToProfile(user.uid),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppTheme.surfaceVariant,
                            backgroundImage: user.avatarUrl != null
                                ? CachedNetworkImageProvider(user.avatarUrl!)
                                : null,
                            child: user.avatarUrl == null
                                ? Icon(Icons.person,
                                    size: 24,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))
                                : null,
                          ),
                          title: Text(
                            user.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          subtitle: user.bio != null && user.bio!.isNotEmpty
                              ? Text(
                                  user.bio!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                )
                              : null,
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}