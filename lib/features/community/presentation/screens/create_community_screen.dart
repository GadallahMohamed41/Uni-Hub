import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
<<<<<<< HEAD
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/services/storage_service.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_bloc.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_event.dart';
import 'package:project_test2/features/community/presentation/bloc/community_list/community_list_state.dart';
=======
import '../../../../../core/theme.dart';
import '../../../../services/storage_service.dart';
import '../bloc/community_list/community_list_bloc.dart';
import '../bloc/community_list/community_list_event.dart';
import '../bloc/community_list/community_list_state.dart';
>>>>>>> 5bfe229f9bee06786262c5ea1015fcaa7aed2f3c

class CreateCommunityScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;
  final String? currentUserAvatarUrl;

  const CreateCommunityScreen({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
    this.currentUserAvatarUrl,
  });

  @override
  State<CreateCommunityScreen> createState() => _CreateCommunityScreenState();
}

class _CreateCommunityScreenState extends State<CreateCommunityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _storage = StorageService();
  String? _imageUrl;
  bool _isUploadingImage = false;
  bool _isPublic = true;
  bool _isSubmitting = false;

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    context.read<CommunityListBloc>().add(CommunityListCreateCommunity(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          createdBy: widget.currentUserId,
          creatorName: widget.currentUserName,
          creatorAvatarUrl: widget.currentUserAvatarUrl,
          imageUrl: _imageUrl,
          isPublic: _isPublic,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<CommunityListBloc, CommunityListState>(
      listener: (context, state) {
        if (state is CommunityListLoaded) {
          if (!state.isCreating) {
            setState(() => _isSubmitting = false);
            if (state.newlyCreated != null) {
              Navigator.pop(context, state.newlyCreated);
            }
            if (state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: AppTheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              context.read<CommunityListBloc>().add(const CommunityListErrorCleared());
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0A0F1E) : const Color(0xFFF0F4FF),
        appBar: AppBar(
          title: const Text('New Community'),
          backgroundColor: isDark ? const Color(0xFF111827) : AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _isSubmitting ? null : () => _submit(context),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Image Picker ─────────────────────────────────────────
                GestureDetector(
                  onTap: _pickImage,
                  child: Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: _imageUrl == null ? AppTheme.primaryGradient : null,
                            color: _imageUrl != null ? Colors.transparent : null,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _isUploadingImage
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(32.0),
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                )
                              : (_imageUrl == null
                                  ? const Icon(Icons.groups_rounded,
                                      color: Colors.white, size: 52)
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: CachedNetworkImage(
                                        imageUrl: _imageUrl!,
                                        fit: BoxFit.cover,
                                        width: 110,
                                        height: 110,
                                        placeholder: (_, __) => const Center(
                                          child: CircularProgressIndicator(color: Colors.white),
                                        ),
                                        errorWidget: (_, __, ___) => const Icon(Icons.groups_rounded,
                                            color: Colors.white, size: 52),
                                      ),
                                    )),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.secondary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF0A0F1E)
                                      : const Color(0xFFF0F4FF),
                                  width: 2.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Community Name ───────────────────────────────────────
                _SectionLabel(label: 'Community Name'),
                const SizedBox(height: 10),
                _PremiumField(
                  controller: _nameCtrl,
                  isDark: isDark,
                  hintText: 'Enter community name...',
                  icon: Icons.group_work_rounded,
                  maxLength: 80,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Name is required' : null,
                  onChanged: (_) => setState(() {}),
                ),
                _CharCounter(current: _nameCtrl.text.length, max: 80),
                const SizedBox(height: 20),

                // ── Description ─────────────────────────────────────────
                _SectionLabel(label: 'Description (optional)'),
                const SizedBox(height: 10),
                _PremiumField(
                  controller: _descCtrl,
                  isDark: isDark,
                  hintText: 'What is this community about?',
                  icon: Icons.description_rounded,
                  maxLength: 300,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                ),
                _CharCounter(current: _descCtrl.text.length, max: 300),
                const SizedBox(height: 24),

                // ── Visibility ──────────────────────────────────────────
                _SectionLabel(label: 'Visibility'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _VisibilityOption(
                        icon: Icons.public_rounded,
                        label: 'Public',
                        subtitle: 'Anyone with link can join',
                        selected: _isPublic,
                        isDark: isDark,
                        onTap: () => setState(() => _isPublic = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _VisibilityOption(
                        icon: Icons.lock_rounded,
                        label: 'Private',
                        subtitle: 'Admin approves requests',
                        selected: !_isPublic,
                        isDark: isDark,
                        onTap: () => setState(() => _isPublic = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Info Banner ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border(
                      left: BorderSide(color: AppTheme.primary, width: 3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppTheme.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'An announcement channel will be automatically created for this community.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.primary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Create Button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isSubmitting
                          ? null
                          : AppTheme.primaryGradient,
                      color:
                          _isSubmitting ? AppTheme.textTertiary : null,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _isSubmitting ? null : () => _submit(context),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Community',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: AppTheme.primary,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _CharCounter extends StatelessWidget {
  final int current;
  final int max;
  const _CharCounter({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$current/$max',
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _PremiumField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String hintText;
  final IconData icon;
  final int maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const _PremiumField({
    required this.controller,
    required this.isDark,
    required this.hintText,
    required this.icon,
    required this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        validator: validator,
        onChanged: onChanged,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textMain,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.only(
                top: maxLines > 1 ? 14 : 0),
            child: Icon(icon, color: AppTheme.textSecondary, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 50),
          alignLabelWithHint: true,
          filled: true,
          fillColor: Colors.transparent,
          counterText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _VisibilityOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _VisibilityOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
              : (isDark ? const Color(0xFF111827) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.primary
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.07)),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
              ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
                size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: selected
                    ? AppTheme.primary
                    : (isDark ? Colors.white : AppTheme.textMain),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

