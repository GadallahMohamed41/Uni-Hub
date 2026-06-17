import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme.dart';
import '../../../../services/storage_service.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../domain/entities/group_entity.dart';
import '../widgets/group_avatar.dart';

class GroupSettingsScreen extends StatefulWidget {
  final GroupEntity group;
  final String currentUserId;

  const GroupSettingsScreen({
    super.key,
    required this.group,
    required this.currentUserId,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final _repo = GroupRepositoryImpl();
  final _storage = StorageService();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late WhoCanSend _whoCanSend;
  late bool _isPublic;
  String? _imageUrl;
  bool _isSaving = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl = TextEditingController(text: widget.group.description);
    _whoCanSend = widget.group.whoCanSend;
    _isPublic = widget.group.isPublic;
    _imageUrl = widget.group.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get isOwner => widget.group.isOwner(widget.currentUserId);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (file == null) return;
    
    setState(() => _isUploadingImage = true);
    try {
      final url = await _storage.uploadGroupImage(File(file.path), widget.currentUserId);
      if (url != null) {
        setState(() => _imageUrl = url);
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _repo.updateGroupInfo(
        groupId: widget.group.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        whoCanSend: _whoCanSend,
        isPublic: _isPublic,
        imageUrl: _imageUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppTheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Group'),
            content: const Text(
                'This action is permanent and cannot be undone. All messages will be lost.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete Forever'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await _repo.deleteGroup(widget.group.id);
    if (context.mounted) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  Future<void> _generateNewLink() async {
    final link = await _repo.generateInviteLink(widget.group.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('New link: $link')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Group Settings'),
        backgroundColor: AppTheme.primary,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Group image
          Center(
            child: GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  if (_isUploadingImage)
                    CircleAvatar(
                      radius: 56,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                      child: const CircularProgressIndicator(color: AppTheme.primary),
                    )
                  else
                    GroupAvatar(
                      imageUrl: _imageUrl,
                      groupName: widget.group.name,
                      radius: 56,
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
                      child: const Icon(Icons.camera_alt_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Name
          const _Label('Group Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            maxLength: 60,
            decoration: const InputDecoration(
              hintText: 'Group name',
              prefixIcon: Icon(Icons.groups_rounded),
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const _Label('Description'),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 3,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Group description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),

          // Who can send
          const _Label('Who Can Send Messages'),
          const SizedBox(height: 8),
          _SegmentedOption(
            options: const ['Everyone', 'Admins Only'],
            selected: _whoCanSend == WhoCanSend.everyone ? 0 : 1,
            onSelected: (i) => setState(() {
              _whoCanSend =
                  i == 0 ? WhoCanSend.everyone : WhoCanSend.adminsOnly;
            }),
          ),
          const SizedBox(height: 16),

          // Visibility
          const _Label('Visibility'),
          const SizedBox(height: 8),
          _SegmentedOption(
            options: const ['Private', 'Public'],
            selected: _isPublic ? 1 : 0,
            onSelected: (i) => setState(() => _isPublic = i == 1),
          ),
          const SizedBox(height: 24),

          // Invite link
          _ActionTile(
            icon: Icons.refresh_rounded,
            label: 'Generate New Invite Link',
            color: AppTheme.primary,
            onTap: _generateNewLink,
          ),
          const SizedBox(height: 8),

          // Delete group (owner only)
          if (isOwner) ...[
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.delete_forever_rounded,
              label: 'Delete Group',
              color: AppTheme.error,
              onTap: () => _deleteGroup(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppTheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SegmentedOption extends StatelessWidget {
  final List<String> options;
  final int selected;
  final void Function(int) onSelected;

  const _SegmentedOption({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: options.asMap().entries.map((e) {
          final isSelected = e.key == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.15 : 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

