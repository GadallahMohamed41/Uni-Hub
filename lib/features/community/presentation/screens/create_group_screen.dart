import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/services/storage_service.dart';
=======
import '../../../../core/theme.dart';
import '../../../../services/storage_service.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

typedef GroupCreatedCallback = void Function(
  String name,
  String description,
  List<String> memberIds,
  String? imageUrl,
  bool isPublic,
);

class CreateGroupScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;
  final GroupCreatedCallback onGroupCreated;
  /// If set, the group will be created inside this community.
  final String? communityId;

  const CreateGroupScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatarUrl,
    required this.onGroupCreated,
    this.communityId,
  });

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _storage = StorageService();
  String? _imageUrl;
  bool _isPublic = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (file == null) return;
    
    setState(() => _isUploading = true);
    try {
      final url = await _storage.uploadGroupImage(File(file.path), widget.currentUserId);
      if (url != null) {
        setState(() => _imageUrl = url);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _create() {
    if (!_formKey.currentState!.validate()) return;
    widget.onGroupCreated(
      _nameCtrl.text.trim(),
      _descCtrl.text.trim(),
      [], // members added separately
      _imageUrl,
      _isPublic,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Group'),
        backgroundColor: AppTheme.primary,
        actions: [
          TextButton(
            onPressed: _create,
            child: const Text(
              'Create',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Group image picker
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      backgroundImage: _imageUrl != null && !_imageUrl!.startsWith('/')
                          ? CachedNetworkImageProvider(_imageUrl!)
                          : (_imageUrl != null ? FileImage(File(_imageUrl!)) as ImageProvider : null),
                      child: _isUploading
                          ? const CircularProgressIndicator(color: AppTheme.primary)
                          : (_imageUrl == null
                              ? const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 40,
                                  color: AppTheme.primary,
                                )
                              : null),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Group Name
            _SectionLabel('Group Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'Enter group name...',
                prefixIcon: Icon(Icons.groups_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Group name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            _SectionLabel('Description (optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'What is this group about?',
                prefixIcon: Icon(Icons.description_rounded),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            // Visibility toggle
            _SectionLabel('Visibility'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ToggleOption(
                      icon: Icons.lock_rounded,
                      label: 'Private',
                      selected: !_isPublic,
                      onTap: () => setState(() => _isPublic = false),
                    ),
                  ),
                  Expanded(
                    child: _ToggleOption(
                      icon: Icons.public_rounded,
                      label: 'Public',
                      selected: _isPublic,
                      onTap: () => setState(() => _isPublic = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isPublic
                  ? 'Anyone can find and join this group via invite link.'
                  : 'Only invited members can join.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

