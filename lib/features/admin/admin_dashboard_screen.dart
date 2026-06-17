import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../providers/posts_provider.dart';
import '../home/post_detail_screen.dart';
import '../profile/user_profile_screen.dart';

import 'package:image_picker/image_picker.dart';
import 'package:project_test2/services/storage_service.dart';
import 'package:project_test2/services/firestore_service.dart';
import '../../widgets/image_detail_screen.dart';
import '../../widgets/custom_confirm_dialog.dart';

class AdminDashboardScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminDashboardScreen({super.key, this.initialTabIndex = 0});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    final idx = widget.initialTabIndex.clamp(0, 2);
    _tabController = TabController(length: 3, vsync: this, initialIndex: idx);
  }
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Schedules'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PendingPostsTab(),
          _ApprovedPostsTab(),
          _UploadSchedulesTab(),
        ],
      ),
    );
  }
}

class _UploadSchedulesTab extends StatefulWidget {
  const _UploadSchedulesTab();

  @override
  State<_UploadSchedulesTab> createState() => _UploadSchedulesTabState();
}

class _UploadSchedulesTabState extends State<_UploadSchedulesTab> {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _selectedUniversity;
  String? _selectedDepartment;
  String? _selectedLevel;
  bool _isUploading = false;

  final Map<String, String> _universities = {
    'Industrial and Energy Technology': 'industrial_energy_technology',
    'College of Applied Health Sciences': 'applied_health_sciences',
  };
  final Map<String, List<Map<String, String>>> _departmentsByUniversity = {
    'industrial_energy_technology': [
      {'label': 'تكنولوجيا المعلومات', 'key': 'it'},
      {'label': 'أجهزه', 'key': 'devices'},
      {'label': 'شبكات', 'key': 'networks'},
      {'label': 'تصنيع غذائي', 'key': 'food_industry'},
    ],
    'applied_health_sciences': [],
  };
  final Map<String, String> _levels = {
    'الفرقه الاولى': 'level1',
    'الفرقه الثانيه': 'level2',
    'الفرقه الثالثه': 'level3',
    'الفرقه الرابعه': 'level4',
  };


  Future<void> _uploadSchedule() async {
    if (_selectedUniversity == null || _selectedDepartment == null || _selectedLevel == null) {
      AppSnackBar.showInfo(context, 'Please select university, department and level');
      return;
    }
    final adminId = context.read<AuthProvider>().userId;

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await image.readAsBytes();
      final url = await _storageService.uploadLectureScheduleHierarchical(
        bytes,
        _selectedUniversity!,
        _selectedDepartment!,
        _selectedLevel!,
      );

      await _firestoreService.upsertScheduleMeta(
        universityKey: _selectedUniversity!,
        departmentKey: _selectedDepartment!,
        levelKey: _selectedLevel!,
        imageUrl: url,
      );


      if (adminId != null) {
        try {
          await _firestoreService.notifyScheduleUploaded(
            fromUserId: adminId,
            universityKey: _selectedUniversity!,
            departmentKey: _selectedDepartment!,
            levelKey: _selectedLevel!,
            imageUrl: url,
          );
        } catch (e) {
          if (mounted) {
            AppSnackBar.showInfo(context, 'Schedule uploaded, but notifications failed');
          }
        }
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Schedule uploaded successfully!');
      }
    } catch (e) {
      if (mounted) {
        // Since we migrated to Firebase, we should show the real error
        AppSnackBar.showError(context, 'Failed to upload: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteSchedule() async {
    if (_selectedUniversity == null || _selectedDepartment == null || _selectedLevel == null) {
      AppSnackBar.showInfo(context, 'Please select university, department and level');
      return;
    }
    await CustomConfirmDialog.show(
      context,
      title: 'Delete Schedule',
      content: 'Are you sure you want to delete this schedule?',
      confirmLabel: 'Delete',
      confirmColor: AppTheme.error,
      icon: Icons.delete_outline_rounded,
      onConfirm: () async {
        try {
          await _firestoreService.deleteSchedule(
            universityKey: _selectedUniversity!,
            departmentKey: _selectedDepartment!,
            levelKey: _selectedLevel!,
          );
          if (mounted) AppSnackBar.showSuccess(context, 'Schedule deleted');
        } catch (e) {
          if (mounted) AppSnackBar.showError(context, 'Failed to delete: $e');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Select University',
              labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
            initialValue: _selectedUniversity,
            items: _universities.entries
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedUniversity = value;
                _selectedDepartment = null;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Select Department',
              labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
            initialValue: _selectedDepartment,
            items: (_selectedUniversity == null
                    ? <DropdownMenuItem<String>>[]
                    : _departmentsByUniversity[_selectedUniversity!]!
                        .map((m) => DropdownMenuItem(
                              value: m['key'],
                              child: Text(m['label']!, overflow: TextOverflow.ellipsis),
                            ))
                        .toList()),
            onChanged: (value) => setState(() => _selectedDepartment = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            style: TextStyle(color: theme.colorScheme.onSurface),
            decoration: InputDecoration(
              labelText: 'Select Level',
              labelStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            dropdownColor: theme.cardTheme.color ?? theme.colorScheme.surface,
            initialValue: _selectedLevel,
            items: _levels.entries
                .map((e) => DropdownMenuItem(
                      value: e.value,
                      child: Text(e.key, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedLevel = value),
          ),
          const SizedBox(height: 24),
          if (_selectedUniversity != null && _selectedDepartment != null && _selectedLevel != null)
            StreamBuilder<Map<String, dynamic>?>(
              stream: _firestoreService.getScheduleMetaStream(
                universityKey: _selectedUniversity!,
                departmentKey: _selectedDepartment!,
                levelKey: _selectedLevel!,
              ),
              builder: (context, snap) {
                final data = snap.data;
                final url = data?["imageUrl"] as String?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (url != null && url.isNotEmpty) ...[
                      Text('Current schedule preview', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageDetailScreen(
                                imageUrl: url,
                                heroTag: 'schedule_preview_$url',
                              ),
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'schedule_preview_$url',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _deleteSchedule,
                        icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                        label: const Text('Delete schedule', style: TextStyle(color: AppTheme.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            ),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadSchedule,
            icon: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) 
                : const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Upload Schedule Image'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPostsTab extends StatelessWidget {
  const _PendingPostsTab();

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();
    final theme = Theme.of(context);

    return StreamBuilder<List<PostModel>>(
      stream: postsProvider.getPendingPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: theme.colorScheme.onSurface)));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text('No pending posts', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return _AdminPostCard(post: post, isPending: true);
          },
        );
      },
    );
  }
}

class _ApprovedPostsTab extends StatelessWidget {
  const _ApprovedPostsTab();

  @override
  Widget build(BuildContext context) {
    final postsProvider = context.watch<PostsProvider>();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: postsProvider.posts.length,
      itemBuilder: (context, index) {
        final post = postsProvider.posts[index];
        return _AdminPostCard(post: post, isPending: false);
      },
    );
  }
}

class _AdminPostCard extends StatelessWidget {
  final PostModel post;
  final bool isPending;

  const _AdminPostCard({required this.post, required this.isPending});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.surfaceVariant),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(userId: post.userId),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundImage: post.userAvatarUrl != null
                        ? CachedNetworkImageProvider(post.userAvatarUrl!)
                        : null,
                    child: post.userAvatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                      ),
                      Text(
                        post.formattedTime,
                        style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.text, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface)),
            if (post.imageUrl != null || post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ImageDetailScreen(
                        imageUrl: post.imageUrl ?? post.imageUrls.first,
                        heroTag: 'admin_post_image_${post.id}',
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: 200,
                  width: double.infinity,
                  child: Hero(
                    tag: 'admin_post_image_${post.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl ?? post.imageUrls.first,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await CustomConfirmDialog.show(
                        context,
                        title: 'Reject Post',
                        content: 'Are you sure you want to reject this post?',
                        confirmLabel: 'Reject',
                        confirmColor: AppTheme.error,
                        icon: Icons.close_rounded,
                        onConfirm: () {
                          final adminId = context.read<AuthProvider>().userId;
                          context.read<PostsProvider>().updatePostStatus(post.id, 'rejected', adminId: adminId);
                        },
                      );
                    },
                    icon: const Icon(Icons.close, color: AppTheme.error),
                    label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await CustomConfirmDialog.show(
                        context,
                        title: 'Approve Post',
                        content: 'Are you sure you want to approve this post?',
                        confirmLabel: 'Approve',
                        confirmColor: Colors.green,
                        icon: Icons.check_circle_outline_rounded,
                        onConfirm: () {
                          final adminId = context.read<AuthProvider>().userId;
                          context.read<PostsProvider>().updatePostStatus(post.id, 'approved', adminId: adminId);
                        },
                      );
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: post.id),
                        ),
                      );
                    },
                    icon: Icon(Icons.visibility_outlined, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    label: Text('View', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      await CustomConfirmDialog.show(
                        context,
                        title: 'Delete Post',
                        content: 'Are you sure you want to delete this post?',
                        confirmLabel: 'Delete',
                        confirmColor: AppTheme.error,
                        icon: Icons.delete_forever_rounded,
                        onConfirm: () {
                          context.read<PostsProvider>().deletePost(post.id, post.imageUrls);
                        },
                      );
                    },
                    icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                    label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
