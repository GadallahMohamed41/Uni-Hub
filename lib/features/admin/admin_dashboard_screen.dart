import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme.dart';
import 'package:project_test2/core/app_snackbar.dart';
import 'package:project_test2/providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../providers/posts_provider.dart';
import '../home/post_detail_screen.dart';

import 'package:image_picker/image_picker.dart';
import 'package:project_test2/services/storage_service.dart';
import 'package:project_test2/services/firestore_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}
class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
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
      {'label': 'تكنولوجيه المعلومات', 'key': 'it'},
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

  String _friendlyUploadError(Object e) {
    final msg = e.toString();
    final lower = msg.toLowerCase();

    if (lower.contains('anonymous') || lower.contains('anon')) {
      return 'Supabase: لازم تفعّل Anonymous Sign-ins من Dashboard > Authentication.';
    }
    if (lower.contains('row-level security') || lower.contains('permission') || lower.contains('not allowed')) {
      return 'Supabase Storage: اعمل Policy للـ bucket `images` تسمح بالرفع (INSERT) للـ authenticated.';
    }
    if (lower.contains('bucket') && lower.contains('not found')) {
      return 'Supabase Storage: bucket `images` مش موجودة (أو اسمها مختلف).';
    }

    return 'Failed to upload schedule: $msg';
  }

  Future<void> _uploadSchedule() async {
    if (_selectedUniversity == null || _selectedDepartment == null || _selectedLevel == null) {
      AppSnackBar.showInfo(context, 'Please select university, department and level');
      return;
    }

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

      final adminId = context.read<AuthProvider>().userId;
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
        AppSnackBar.showError(context, _friendlyUploadError(e));
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
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select University',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
            initialValue: _selectedUniversity,
            items: _universities.entries
                .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
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
            decoration: InputDecoration(
              labelText: 'Select Department',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
            initialValue: _selectedDepartment,
            items: (_selectedUniversity == null
                    ? <DropdownMenuItem<String>>[]
                    : _departmentsByUniversity[_selectedUniversity!]!
                        .map((m) => DropdownMenuItem(value: m['key'], child: Text(m['label']!)))
                        .toList()),
            onChanged: (value) => setState(() => _selectedDepartment = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Select Level',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppTheme.surface,
            ),
            initialValue: _selectedLevel,
            items: _levels.entries
                .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
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
                      const Text('Current schedule preview', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          height: 180,
                          fit: BoxFit.contain,
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
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

    return StreamBuilder<List<PostModel>>(
      stream: postsProvider.getPendingPostsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final posts = snapshot.data ?? [];

        if (posts.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: AppTheme.textTertiary),
                SizedBox(height: 16),
                Text('No pending posts', style: TextStyle(color: AppTheme.textSecondary)),
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

    // This gets approved posts via the standard stream
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: post.userAvatarUrl != null
                      ? CachedNetworkImageProvider(post.userAvatarUrl!)
                      : null,
                  child: post.userAvatarUrl == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        post.formattedTime,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.text, style: const TextStyle(fontSize: 15)),
            if (post.imageUrl != null || post.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl ?? post.imageUrls.first,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            if (isPending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      FirestoreService().deletePostDeep(post.id);
                    },
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<PostsProvider>().updatePostStatus(post.id, 'approved');
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                      // Navigate to detail to view comments/etc
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(postId: post.id),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('View'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                       context.read<PostsProvider>().deletePost(post.id, post.imageUrls);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
