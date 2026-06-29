import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/core/theme/theme_provider.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';

class UniversityFeedHeader extends StatelessWidget {
  final String? userId;
  final VoidCallback onTapAvatar;
  final VoidCallback onTapComposer;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapVideo;
  final VoidCallback onTapEvent;
  final VoidCallback onTapNotifications;
  final VoidCallback onTapSearch;

  const UniversityFeedHeader({
    super.key,
    required this.userId,
    required this.onTapAvatar,
    required this.onTapComposer,
    required this.onTapPhoto,
    required this.onTapVideo,
    required this.onTapEvent,
    required this.onTapNotifications,
    required this.onTapSearch,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final topPadding = MediaQuery.of(context).padding.top;

    final name = user?.name ?? 'User';
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M';
    final avatarUrl = (user?.avatarUrl ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.8, -0.5),
          end: Alignment(-0.8, 0.5),
          colors: [
            Color(0xFF0F3CC9),
            Color(0xFF1A56DB),
            Color(0xFF2563EB),
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: topPadding > 0 ? topPadding + 2 : 12,
        left: 18,
        right: 18,
        bottom: 3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Row 1: Title + Icons ─────────────────────────────────────────
          Row(
            children: [
              // Title (left)
              Expanded(
                child: Text(
                  'University Feed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // Icons (right)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Theme Toggle
                  _buildTopIconButton(
                    icon: themeProvider.isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                  const SizedBox(width: 7),

                  // Notification Bell
                  StreamBuilder<int>(
                    stream: userId == null
                        ? const Stream<int>.empty()
                        : FirestoreService().getUnreadNotificationsCountStream(userId!),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildTopIconButton(
                            icon: Icons.notifications_none_rounded,
                            onTap: onTapNotifications,
                          ),
                          if (count > 0)
                            Positioned(
                              top: -1,
                              right: -1,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFF1A56DB),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 7),

                  // Search
                  _buildTopIconButton(
                    icon: Icons.search_rounded,
                    onTap: onTapSearch,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Row 2: Avatar + Compose Bar ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar
              GestureDetector(
                onTap: onTapAvatar,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    image: hasAvatar
                        ? DecorationImage(
                            image: CachedNetworkImageProvider(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasAvatar
                      ? null
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),

              // Compose Bar
              Expanded(
                child: GestureDetector(
                  onTap: onTapComposer,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 15,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          "What's on your mind?",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Row 3: Photo / Video / Event ─────────────────────────────────
          Row(
            
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            
              _buildMediaButton(
                
                icon: Icons.image_rounded,
                label: 'Photo',
                color: const Color(0xFF60A5FA),
                onTap: onTapPhoto,
              ),
              const SizedBox(width: 36),
              _buildMediaButton(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: const Color(0xFFD946EF),
                onTap: onTapVideo,
              ),
              const SizedBox(width: 36),
              _buildMediaButton(
                icon: Icons.calendar_today_rounded,
                label: 'Event',
                color: const Color(0xFFFBBF24),
                onTap: onTapEvent,
              ),
            ],
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
