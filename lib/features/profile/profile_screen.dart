import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/core/page_transitions.dart';
import 'package:project_test2/core/app_snackbar.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../services/firestore_service.dart';
import '../auth/login_screen.dart';
import '../../core/animations.dart';
import '../admin/admin_dashboard_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'lectures_section_screen.dart';
import 'reposts_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isUploading = false;
  File? _localAvatarFile;

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      await context.read<AuthProvider>().signOut();
      Navigator.pushReplacement(
        context,
        PageTransitions.fadeTransition(const LoginScreen()),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    
    if (user == null) return;

    // Show options dialog
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 24),
            const Text(
              "Change Profile Photo",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              onTap: () => Navigator.pop(context, 'gallery'),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.photo_library_rounded, color: AppTheme.info),
              ),
              title: const Text("Choose from Gallery", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () => Navigator.pop(context, 'remove'),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppTheme.error),
              ),
              title: const Text("Remove Photo", style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (action == null) return;

    if (action == 'remove') {
      setState(() {
        _isUploading = true;
        _localAvatarFile = null;
      });
      try {
        await _firestoreService.updateUserAvatar(user.uid, '');
        final updatedUser = user.copyWith(avatarUrl: '');
        authProvider.updateCurrentUser(updatedUser);
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Profile photo removed');
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, 'Failed to remove');
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
      return;
    }

    final source = ImageSource.gallery;

    final XFile? image = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75);

    if (image == null) return;

    setState(() {
      _isUploading = true;
      if (!kIsWeb) {
        _localAvatarFile = File(image.path);
      }
    });

    try {
      final oldAvatarUrl = (user.avatarUrl ?? '').trim();
      final bytes = await image.readAsBytes();

      final rawImageUrl = await _storageService.uploadProfileImageSigned(bytes, user.uid);

      if (rawImageUrl == null) {
        if (mounted) {
          AppSnackBar.showError(context, 'Failed to upload profile photo. Check your connection.');
        }
        return;
      }

      // Bust caches (same storage path can keep same URL/token)
      final avatarUrl = rawImageUrl.contains('?')
          ? '$rawImageUrl&v=${DateTime.now().millisecondsSinceEpoch}'
          : '$rawImageUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      // Update Firestore
      await _firestoreService.updateUserAvatar(user.uid, avatarUrl);
      
      // Update local user
      final updatedUser = user.copyWith(avatarUrl: avatarUrl);
      authProvider.updateCurrentUser(updatedUser);
      if (oldAvatarUrl.isNotEmpty) {
        await CachedNetworkImage.evictFromCache(oldAvatarUrl);
      }
      await CachedNetworkImage.evictFromCache(avatarUrl);

      if (mounted) {
        setState(() => _localAvatarFile = null);
        AppSnackBar.showSuccess(context, 'Profile photo updated!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to upload profile photo. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;
    final avatarUrl = (user?.avatarUrl ?? '').trim();
    final hasAvatarUrl = avatarUrl.isNotEmpty;
    final ImageProvider<Object>? avatarProvider = _localAvatarFile != null
        ? FileImage(_localAvatarFile!) as ImageProvider<Object>
        : (hasAvatarUrl ? CachedNetworkImageProvider(avatarUrl) as ImageProvider<Object> : null);
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Professional Gradient Header
                Container(
                  height: 240,
                  decoration: const BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
                  ),
                ),
                
                // Profile Card
                Positioned(
                  top: 160,
                  child: FadeInAnimation(
                    delay: 200,
                  child: Container(
                      width: MediaQuery.of(context).size.width * 0.9,
                      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                    decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                    ),
                    child: Column(
                        children: [
                          Text(
                            user?.name ?? "User",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMain,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user?.department ?? user?.bio ?? "Student",
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                          if (user?.studentId != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "ID: ${user!.studentId}",
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Profile Picture with Edit Button
                Positioned(
                  top: 100,
                  child: FadeInAnimation(
                    delay: 100,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: AppTheme.surfaceVariant,
                              backgroundImage: avatarProvider,
                              child: _isUploading
                                  ? const CircularProgressIndicator(color: AppTheme.primary)
                                  : (avatarProvider == null
                                      ? const Icon(Icons.person, size: 56, color: AppTheme.textTertiary)
                                      : null),
                            ),
                          ),
                          // Edit Icon
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 140),

            // Settings List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (user?.isAdmin == true)
                    FadeInAnimation(
                      delay: 250,
                      child: _buildSettingTile(
                        Icons.admin_panel_settings_outlined,
                        "Admin Dashboard",
                        AppTheme.error,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransitions.combinedTransition(const AdminDashboardScreen()),
                          );
                        },
                      ),
                    ),
                  
                  FadeInAnimation(
                    delay: 300,
                    child: _buildSettingTile(
                      Icons.person_outline_rounded,
                      "Edit Profile",
                      AppTheme.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransitions.combinedTransition(const EditProfileScreen()),
                        );
                      },
                    ),
                  ),
                  
                  if (user?.isAdmin != true)
                    FadeInAnimation(
                      delay: 400,
                      child: _buildSettingTile(
                        Icons.calendar_month_rounded,
                        "Lecture Schedule",
                        AppTheme.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransitions.combinedTransition(const LecturesSectionScreen()),
                          );
                        },
                      ),
                    ),
                  FadeInAnimation(
                    delay: 450,
                    child: const SizedBox.shrink(),
                  ),
                  FadeInAnimation(
                    delay: 500,
                    child: _buildSettingTile(
                      Icons.lock_outline_rounded,
                      "Privacy & Security",
                      AppTheme.success,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransitions.combinedTransition(const PrivacySecurityScreen()),
                        );
                      },
                    ),
                  ),
                  FadeInAnimation(
                    delay: 520,
                    child: _buildSettingTile(
                      Icons.repeat_rounded,
                      "Reposts",
                      AppTheme.info,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageTransitions.combinedTransition(const RepostsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInAnimation(
                    delay: 550,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.error.withOpacity(0.2),
                        ),
                      ),
                      child: ListTile(
                        onTap: () => _handleLogout(context),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.logout_rounded, color: AppTheme.error),
                        ),
                        title: const Text(
                          "Logout",
                          style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppTheme.error.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppTheme.textMain,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: AppTheme.textTertiary,
        ),
      ),
    );
  }
}
