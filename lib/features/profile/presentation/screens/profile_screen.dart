import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:project_test2/features/profile/presentation/screens/testimonials_user_screen.dart';
import 'package:project_test2/features/profile/presentation/widgets/fullscreen_image_viewer.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:project_test2/features/auth/presentation/providers/auth_provider.dart';
import 'package:project_test2/features/profile/data/models/user_model.dart';
import 'package:project_test2/core/providers/locale_provider.dart';
import 'package:project_test2/features/home/data/models/post_model.dart';
import 'package:project_test2/features/home/presentation/widgets/comments_sheet.dart';
import 'package:project_test2/features/home/presentation/widgets/post_card.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/core/services/firestore_service.dart';
import 'package:project_test2/core/utils/app_snackbar.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/utils/page_transitions.dart';
import 'package:project_test2/features/auth/presentation/screens/login_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/privacy_security_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/lectures_section_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/reposts_screen.dart';
import 'package:project_test2/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:project_test2/features/profile/presentation/screens/cv_file_user_screen.dart';
import 'package:project_test2/features/connections/presentation/screens/connections_screen.dart';
import 'package:project_test2/core/widgets/custom_confirm_dialog.dart';
import 'package:project_test2/features/profile/presentation/screens/followers_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ImagePicker _picker = ImagePicker();
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isUploading = false;
  File? _localAvatarFile;
  bool _isCoverUploading = false;
  File? _localCoverFile;

  Future<void> _handleLogout(BuildContext context) async {
    await CustomConfirmDialog.show(
      context,
      title: 'Logout',
      content: 'Are you sure you want to logout?',
      confirmLabel: 'Logout',
      confirmColor: AppTheme.error,
      icon: Icons.logout_rounded,
      onConfirm: () async {
        await context.read<AuthProvider>().signOut(context);
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            PageTransitions.fadeTransition(const LoginScreen()),
          );
        }
      },
    );
  }

  Future<void> _pickAndUploadImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Change Profile Photo",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 24),
              if ((user.avatarUrl ?? '').trim().isNotEmpty)
                ListTile(
                  onTap: () => Navigator.pop(context, 'view'),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image_rounded,
                        color: AppTheme.primary),
                  ),
                  title: Text("View Photo",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                ),
              ListTile(
                onTap: () => Navigator.pop(context, 'gallery'),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppTheme.info),
                ),
                title: Text("Choose from Gallery",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ),
              ListTile(
                onTap: () => Navigator.pop(context, 'remove'),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_forever_rounded,
                      color: AppTheme.error),
                ),
                title: Text("Remove Photo",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    if (!mounted) return;

    if (action == 'view') {
      if ((user.avatarUrl ?? '').trim().isNotEmpty) {
        Navigator.push(
          context,
          PageTransitions.combinedTransition(
            FullscreenImageViewer(
                imageProvider: CachedNetworkImageProvider(user.avatarUrl!)),
          ),
        );
      } else {
        AppSnackBar.showInfo(context, 'No profile photo to view');
      }
      return;
    }

    if (action == 'remove') {
      setState(() {
        _isUploading = true;
        _localAvatarFile = null;
      });
      try {
        await _firestoreService.updateUserAvatar(user.uid, '');
        if (!mounted) return;
        authProvider.updateCurrentUser(user.copyWith(avatarUrl: ''));
        AppSnackBar.showSuccess(context, 'Profile photo removed');
      } catch (_) {
        if (!mounted) return;
        AppSnackBar.showError(context, 'Failed to remove');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75);
    if (image == null) return;

    setState(() {
      _isUploading = true;
      if (!kIsWeb) _localAvatarFile = File(image.path);
    });

    try {
      final bytes = await image.readAsBytes();
      final rawImageUrl =
          await _storageService.uploadProfileImageSigned(bytes, user.uid);
      if (!mounted) return;
      if (rawImageUrl == null) {
        AppSnackBar.showError(context, 'Failed to upload profile photo.');
        return;
      }
      final avatarUrl = rawImageUrl.contains('?')
          ? '$rawImageUrl&v=${DateTime.now().millisecondsSinceEpoch}'
          : '$rawImageUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await _firestoreService.updateUserAvatar(user.uid, avatarUrl);
      await CachedNetworkImage.evictFromCache(avatarUrl);
      if (!mounted) return;
      authProvider.updateCurrentUser(user.copyWith(avatarUrl: avatarUrl));
      setState(() {
        _localAvatarFile = null;
      });
      AppSnackBar.showSuccess(context, 'Profile photo updated!');
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, 'Failed to upload profile photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _pickAndUploadCoverImage() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    if (user == null) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text("Change Cover Photo",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface)),
              const SizedBox(height: 24),
              if ((user.coverUrl ?? '').trim().isNotEmpty)
                ListTile(
                  onTap: () => Navigator.pop(context, 'view'),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.image_rounded,
                        color: AppTheme.primary),
                  ),
                  title: Text("View Cover Photo",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                ),
              ListTile(
                onTap: () => Navigator.pop(context, 'gallery'),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: AppTheme.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppTheme.info),
                ),
                title: Text("Choose from Gallery",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface)),
              ),
              if ((user.coverUrl ?? '').trim().isNotEmpty)
                ListTile(
                  onTap: () => Navigator.pop(context, 'remove'),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.delete_forever_rounded,
                        color: AppTheme.error),
                  ),
                  title: Text("Remove Cover Photo",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface)),
                ),
            ],
          ),
        );
      },
    );

    if (action == null) return;
    if (!mounted) return;

    if (action == 'view') {
      if ((user.coverUrl ?? '').trim().isNotEmpty) {
        Navigator.push(
          context,
          PageTransitions.combinedTransition(
            FullscreenImageViewer(
                imageProvider: CachedNetworkImageProvider(user.coverUrl!)),
          ),
        );
      } else {
        AppSnackBar.showInfo(context, 'No cover photo to view');
      }
      return;
    }

    if (action == 'remove') {
      setState(() {
        _isCoverUploading = true;
        _localCoverFile = null;
      });
      try {
        await _firestoreService.updateUserCover(user.uid, '');
        if (!mounted) return;
        authProvider.updateCurrentUser(user.copyWith(coverUrl: ''));
        AppSnackBar.showSuccess(context, 'Cover photo removed');
      } catch (_) {
        if (!mounted) return;
        AppSnackBar.showError(context, 'Failed to remove');
      } finally {
        if (mounted) setState(() => _isCoverUploading = false);
      }
      return;
    }

    final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isCoverUploading = true;
      if (!kIsWeb) _localCoverFile = File(image.path);
    });

    try {
      final bytes = await image.readAsBytes();
      final rawImageUrl =
          await _storageService.uploadCoverImageSigned(bytes, user.uid);
      if (!mounted) return;
      if (rawImageUrl == null) {
        AppSnackBar.showError(context, 'Failed to upload cover photo.');
        return;
      }
      final coverUrl = rawImageUrl.contains('?')
          ? '$rawImageUrl&v=${DateTime.now().millisecondsSinceEpoch}'
          : '$rawImageUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      await _firestoreService.updateUserCover(user.uid, coverUrl);
      await CachedNetworkImage.evictFromCache(coverUrl);
      if (!mounted) return;
      authProvider.updateCurrentUser(user.copyWith(coverUrl: coverUrl));
      setState(() {
        _localCoverFile = null;
      });
      AppSnackBar.showSuccess(context, 'Cover photo updated!');
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(
          context, 'Failed to upload cover photo. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isCoverUploading = false;
        });
      }
    }
  }

  Future<void> _openlLink(String link) async {
    if (link.trim().isEmpty) {
      AppSnackBar.showError(context, 'Link is empty');
      return;
    }

    final raw = link.trim();
    final finalLink = raw.startsWith('http') ? raw : 'https://$raw';
    final url = Uri.tryParse(finalLink);
    if (url == null) {
      AppSnackBar.showError(context, 'Invalid link');
      return;
    }

    try {
      final ok = await launchUrl(
        url,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!mounted) return;
      if (!ok) {
        AppSnackBar.showError(context, 'Could not open link');
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Could not open link');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = context.select<AuthProvider, UserModel?>((auth) => auth.currentUser);
    final avatarUrl = (user?.avatarUrl ?? '').trim();
    final avatarProvider = _localAvatarFile != null
        ? FileImage(_localAvatarFile!) as ImageProvider<Object>
        : (avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        width: MediaQuery.of(context).size.width * 0.78,
        child: Container(
          margin: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 20,
            bottom: MediaQuery.paddingOf(context).bottom + 90,
            left: 12,
            right: 12,
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                blurRadius: 30,
                offset: const Offset(4, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.menu_open_rounded,
                          color: AppTheme.primary, size: 28),
                    ),
                    const SizedBox(width: 8),
                    // Language Toggle Button
                    Builder(
                      builder: (ctx) {
                        final localeProv = ctx.watch<LocaleProvider>();
                        final isAr = localeProv.isArabic;
                        return GestureDetector(
                          onTap: () => localeProv.toggleLocale(),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isAr
                                  ? AppTheme.primary
                                  : AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(19),
                              border: Border.all(
                                color: AppTheme.primary,
                                width: 1.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 16,
                                  color: isAr ? Colors.white : AppTheme.primary,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isAr ? 'EN' : 'ع',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isAr ? Colors.white : AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Menu",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                if (user?.isAdmin == true)
                  _buildSettingTile(
                      context,
                      Icons.admin_panel_settings_outlined,
                      "Admin Dashboard",
                      AppTheme.error, onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        PageTransitions.combinedTransition(
                            const AdminDashboardScreen()));
                  }),
                _buildSettingTile(context, Icons.person_outline_rounded,
                    "Edit Profile", AppTheme.info, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      PageTransitions.combinedTransition(
                          const EditProfileScreen()));
                }),
                if (user?.isAdmin != true)
                  _buildSettingTile(context, Icons.calendar_month_rounded,
                      "Lecture Schedule", AppTheme.primary, onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        PageTransitions.combinedTransition(
                            const LecturesSectionScreen()));
                  }),
                _buildSettingTile(context, Icons.lock_outline_rounded,
                    "Privacy & Security", AppTheme.success, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      PageTransitions.combinedTransition(
                          const PrivacySecurityScreen()));
                }),
                _buildSettingTile(
                    context, Icons.repeat_rounded, "Reposts", AppTheme.info,
                    onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      PageTransitions.combinedTransition(
                          const RepostsScreen()));
                }),
                _buildSettingTile(
                    context, Icons.file_present_rounded, "My CV", AppTheme.info,
                    onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      PageTransitions.combinedTransition(const CvFileUser()));
                }),
                _buildSettingTile(context, Icons.military_tech_rounded,
                    "My Certificate", AppTheme.primaryDark, onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      PageTransitions.combinedTransition(
                          const TestimonialsUser()));
                }),
                const SizedBox(height: 16),
                Divider(color: Colors.grey.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppTheme.error.withValues(alpha: 0.2))),
                  child: ListTile(
                    onTap: () {
                      Navigator.pop(context);
                      _handleLogout(context);
                    },
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.logout_rounded,
                            color: AppTheme.error)),
                    title: const Text("Logout",
                        style: TextStyle(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: 16, color: AppTheme.error.withValues(alpha: 0.5)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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
                      onTap: _isCoverUploading ? null : _pickAndUploadCoverImage,
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
                              // Cover image
                              if (_localCoverFile != null)
                                Image.file(
                                  _localCoverFile!,
                                  fit: BoxFit.cover,
                                )
                              else if (user?.coverUrl != null && user!.coverUrl!.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: user.coverUrl!,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(milliseconds: 300),
                                ),
                              // Dark overlay on cover image
                              if (_localCoverFile != null || (user?.coverUrl != null && user!.coverUrl!.isNotEmpty))
                                Container(
                                  color: Colors.black.withValues(alpha: 0.35),
                                ),
                              // Custom Painter for decorative elements (only if NO cover image is present)
                              if (_localCoverFile == null && (user?.coverUrl == null || user!.coverUrl!.isEmpty))
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
                              // Uploading loader
                              if (_isCoverUploading)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.cyan,
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
                      Container(
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
                              user?.name ?? "User",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
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
                            // Lighter pill container for Bio text
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1D2840) : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                user?.bio?.trim().isNotEmpty == true
                                    ? user!.bio!
                                    : "Software Engineer | Flutter Developer | Problem Solver",
                                textAlign: TextAlign.center,
                                textWidthBasis: TextWidthBasis.longestLine,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 3. Menu/Drawer Button — always show menu on own profile
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
                          Icons.menu_rounded,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                    ),
                  ),
                  // 4. Cover Camera/Edit Button
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 12,
                    right: 16,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          icon: _isCoverUploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.camera_alt_rounded, color: Colors.white),
                          onPressed: _isCoverUploading ? null : _pickAndUploadCoverImage,
                        ),
                      ),
                    ),
                  ),
                  // 5. Centered Avatar Section (Standard circular image with no glowing neon ring)
                  Positioned(
                    top: 154,
                    child: GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 4.0,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 53,
                              backgroundColor: theme.cardTheme.color ?? theme.colorScheme.surface,
                              backgroundImage: avatarProvider,
                              child: _isUploading
                                  ? const CircularProgressIndicator(color: Colors.cyan)
                                  : (avatarProvider == null
                                      ? const Icon(
                                          Icons.person,
                                          size: 53,
                                          color: Colors.grey,
                                        )
                                      : null),
                            ),
                          ),
                          // Camera Badge at bottom-right of avatar
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.blue, Colors.cyan],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding:
                  const EdgeInsets.only(top: 0, bottom: 0, left: 20, right: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(15)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (user?.githubLink?.isNotEmpty ?? false)
                      Material(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _openlLink(user!.githubLink!),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: SvgPicture.asset(
                              'lib/assets/icons/gethub.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    if (user?.linkedinLink?.isNotEmpty ?? false)
                      const SizedBox(width: 12),
                    if (user?.linkedinLink?.isNotEmpty ?? false)
                      InkWell(
                        onTap: () => _openlLink(user!.linkedinLink!),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFF0A66C2),
                              borderRadius: BorderRadius.circular(10)),
                          child: SvgPicture.asset(
                              'lib/assets/icons/linkedin.svg',
                              width: 16,
                              height: 16,
                              colorFilter: const ColorFilter.mode(
                                  Colors.white, BlendMode.srcIn)),
                        ),
                      ),
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const CvFileUser()),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF607D8B),
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
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Stats banner (Posts • Connections • Followers) ──────────
            if (user != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ProfileStats(userId: user.uid),
              ),

            if (user != null) ...[
              const SizedBox(height: 10),
              Divider(
                color: Colors.grey.withValues(alpha: 0.3),
                endIndent: 50,
                indent: 50,
              ),
              const SizedBox(height: 8),
              _MyPostsSection(userId: user.uid),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile(
      BuildContext context, IconData icon, String title, Color color,
      {VoidCallback? onTap}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: theme.colorScheme.onSurface)),
        trailing: Icon(Icons.arrow_forward_ios_rounded,
            size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
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


// ═══════════════════════════════════════════════════════════════════════════════
// Stats Banner  (Posts • Connections • Followers)
// ═══════════════════════════════════════════════════════════════════════════════
class _ProfileStats extends StatefulWidget {
  final String userId;
  const _ProfileStats({required this.userId});

  @override
  State<_ProfileStats> createState() => _ProfileStatsState();
}

class _ProfileStatsState extends State<_ProfileStats> {
  final FirestoreService _firestoreService = FirestoreService();

  int _followersCount = 0;
  bool _isFollowing = false;
  bool _isLoading = false;
  String? _currentUserId;
  late Stream<QuerySnapshot> _connectionsStream;

  @override
  void initState() {
    super.initState();
    _loadData();
    _connectionsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('connections')
        .snapshots();
  }

  @override
  void didUpdateWidget(covariant _ProfileStats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _connectionsStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('connections')
          .snapshots();
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    _currentUserId = authProvider.currentUser?.uid;

    if (_currentUserId == null) return;

    _followersCount = await _firestoreService.getFollowersCount(widget.userId);
    _isFollowing =
        await _firestoreService.isFollowing(_currentUserId!, widget.userId);

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) return;
    if (_currentUserId == widget.userId) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isFollowing) {
        final success = await _firestoreService.unfollowUser(
            _currentUserId!, widget.userId);
        if (success) {
          setState(() {
            _followersCount--;
            _isFollowing = false;
          });
        }
      } else {
        final success =
            await _firestoreService.followUser(_currentUserId!, widget.userId);
        if (success) {
          setState(() {
            _followersCount++;
            _isFollowing = true;
          });
        }
      }
    } catch (e) {
      // silent
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    _currentUserId = context.select<AuthProvider, String?>((auth) => auth.currentUser?.uid);
    final isOwnProfile = _currentUserId == widget.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: _connectionsStream,
      builder: (_, connSnap) {
        final connectionsCount = connSnap.data?.docs.length ?? 0;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [
                      AppTheme.primary.withValues(alpha: 0.06),
                      AppTheme.secondary.withValues(alpha: 0.04)
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.12),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ConnectionsScreen(initialTabIndex: 1),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _StatItem(
                      icon: Icons.people_rounded,
                      count: connectionsCount,
                      label: 'Connections',
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
              Expanded(
                child: isOwnProfile
                    ? GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FollowersScreen(
                                userId: widget.userId,
                                title: 'My Followers',
                              ),
                            ),
                          );
                        },
                        child: _StatItem(
                          icon: Icons.person_add_alt_1_rounded,
                          count: _followersCount,
                          label: 'Followers',
                          color: AppTheme.warning,
                        ),
                      )
                    : GestureDetector(
                        onTap: _isLoading ? null : _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: _isFollowing
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.primary.withValues(alpha: 0.1),
                            border: Border.all(
                              color: _isFollowing
                                  ? AppTheme.success.withValues(alpha: 0.2)
                                  : AppTheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isFollowing
                                    ? Icons.check_circle_rounded
                                    : Icons.person_add_alt_1_rounded,
                                color: _isFollowing
                                    ? AppTheme.success
                                    : AppTheme.primary,
                                size: 15,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isFollowing ? 'Following' : 'Follow',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _isFollowing
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                              Text(
                                '$_followersCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: _isFollowing
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 1),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// My Posts Section with Follow Button (Saved in Firebase)
// ═══════════════════════════════════════════════════════════════════════════════
class _MyPostsSection extends StatefulWidget {
  final String userId;
  const _MyPostsSection({required this.userId});

  @override
  State<_MyPostsSection> createState() => _MyPostsSectionState();
}

class _MyPostsSectionState extends State<_MyPostsSection> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isFollowing = false;
  bool _isLoading = false;
  String? _currentUserId;
  late Stream<QuerySnapshot> _postsStream;

  @override
  void initState() {
    super.initState();
    _postsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: widget.userId)
        .snapshots();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFollowData();
    });
  }

  @override
  void didUpdateWidget(covariant _MyPostsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _postsStream = FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: widget.userId)
          .snapshots();
      _loadFollowData();
    }
  }

  Future<void> _loadFollowData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.currentUser?.uid;

    if (_currentUserId == null) return;
    if (_currentUserId == widget.userId) return;

    _isFollowing =
        await _firestoreService.isFollowing(_currentUserId!, widget.userId);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId == null) return;
    if (_currentUserId == widget.userId) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isFollowing) {
        final success = await _firestoreService.unfollowUser(
            _currentUserId!, widget.userId);
        if (success) {
          setState(() => _isFollowing = false);
        }
      } else {
        final success =
            await _firestoreService.followUser(_currentUserId!, widget.userId);
        if (success) {
          setState(() => _isFollowing = true);
        }
      }
    } catch (e) {
      // silent
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _currentUserId = context.select<AuthProvider, String?>((auth) => auth.currentUser?.uid);
    final isOwnProfile = _currentUserId == widget.userId;

    return StreamBuilder<QuerySnapshot>(
      stream: _postsStream,
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];

        final sorted = [...docs];
        sorted.sort((a, b) {
          final aTime = (a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          final bTime = (b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.article_rounded,
                            color: AppTheme.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Posts',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${sorted.length}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!isOwnProfile)
                    GestureDetector(
                      onTap: _isLoading ? null : _toggleFollow,
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
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isFollowing ? "following" : "follow",
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
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    children: [
                      Icon(Icons.post_add_rounded,
                          size: 40, color: AppTheme.textTertiary),
                      SizedBox(height: 8),
                      Text(
                        'No posts yet',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  try {
                    final post = PostModel.fromFirestore(sorted[i]);
                    return PostCard(
                      post: post,
                      currentProfileUserId: widget.userId,
                      onShowComment: (p) => showCommentsSheet(context, p),
                      onShowRepost: (p) {},
                      onShowReactionPicker: (p, pos) {},
                    );
                  } catch (_) {
                    return const SizedBox.shrink();
                  }
                },
              ),
          ],
        );
      },
    );
  }
}
