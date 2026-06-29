/// Enhanced Create Post Sheet — wraps the existing CreatePostSheet
/// with Privacy, Mention, and Feeling features.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/app_snackbar.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/posts_provider.dart';
import '../../../../services/post_enhancements_service.dart';
import '../create_post_sheet.dart' show DashedBorderPainter;
import 'privacy_control.dart';
import 'feeling_selector.dart';
import 'mention_system.dart';

class EnhancedCreatePostSheet extends StatefulWidget {
  final List<Uint8List>? initialImages;
  final Uint8List? initialVideo;
  const EnhancedCreatePostSheet({super.key, this.initialImages, this.initialVideo});

  @override
  State<EnhancedCreatePostSheet> createState() => _EnhancedCreatePostSheetState();
}

class _EnhancedCreatePostSheetState extends State<EnhancedCreatePostSheet> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();
  final PostEnhancementsService _enhService = PostEnhancementsService();

  String postText = "";
  List<Uint8List> selectedImagesBytes = [];
  Uint8List? selectedVideoBytes;
  int previewIndex = 0;

  // New feature state
  PostPrivacy _privacy = PostPrivacy.public;
  Feeling? _feeling;
  late MentionController _mentionController;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null) selectedImagesBytes = List.from(widget.initialImages!);
    if (widget.initialVideo != null) selectedVideoBytes = widget.initialVideo;

    final userId = context.read<AuthProvider>().userId ?? '';
    _mentionController = MentionController(
      currentUserId: userId,
      textController: _textController,
      onTextChanged: (text) => setState(() => postText = text),
    );
    _mentionController.loadConnections().then((_) { 
      if (mounted) setState(() {}); 
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _mentionController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) return;
      final bytesList = <Uint8List>[];
      for (final img in images) bytesList.add(await img.readAsBytes());
      setState(() { selectedImagesBytes = bytesList; previewIndex = 0; selectedVideoBytes = null; });
    } catch (e) { if (mounted) AppSnackBar.showError(context, 'Failed to pick images: $e'); }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final bytes = await video.readAsBytes();
      setState(() { selectedVideoBytes = bytes; selectedImagesBytes = []; });
    } catch (e) { if (mounted) AppSnackBar.showError(context, 'Failed to pick video: $e'); }
  }

  Future<void> _submitPost() async {
    final authProvider = context.read<AuthProvider>();
    final postsProvider = context.read<PostsProvider>();
    final user = authProvider.currentUser;
    if (user == null) { AppSnackBar.showError(context, 'You must be logged in to post'); return; }
    if (user.isBlocked) {
      if (user.blockedUntil != null && user.blockedUntil!.isAfter(DateTime.now())) {
        AppSnackBar.showError(context, 'You are blocked from posting until ${user.blockedUntil.toString().split('.')[0]}');
      } else if (user.blockedUntil == null) {
        AppSnackBar.showError(context, 'You are permanently blocked from posting');
      }
      return;
    }

    final success = await postsProvider.createPost(
      userId: user.uid,
      userName: user.name,
      userBio: user.bio ?? 'Student',
      userAvatarUrl: user.avatarUrl,
      text: postText,
      imageBytesList: selectedImagesBytes,
      videoBytes: selectedVideoBytes,
      status: user.isAdmin ? 'approved' : 'pending',
      privacyLevel: privacyToFirestore(_privacy),
      feeling: _feeling?.firestoreValue,
      mentionedUserIds: _mentionController.mentionedUserIds.toList(),
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      if (!user.isAdmin) AppSnackBar.showInfo(context, 'Post submitted for approval');
    } else {
      AppSnackBar.showError(context, postsProvider.error ?? 'Failed to create post');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = context.select<AuthProvider, dynamic>((auth) => auth.currentUser);
    final name = user?.name ?? 'User';
    final initials = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    final avatarUrl = (user?.avatarUrl ?? '').trim();
    final hasAvatar = avatarUrl.isNotEmpty;
    final media = MediaQuery.of(context);
    final keyboardHeight = media.viewInsets.bottom;
    final sheetHeight = (media.size.height * 0.85).clamp(420.0, media.size.height);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180), curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: ui.Radius.circular(28)),
        ),
        child: Column(children: [
          // Top Glow Line
          Container(height: 3, decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: ui.Radius.circular(28)),
            gradient: LinearGradient(colors: [
              colorScheme.primary.withValues(alpha: 0.1), colorScheme.primary, colorScheme.primary.withValues(alpha: 0.1),
            ]),
          )),
          // Handle Bar
          Container(margin: const EdgeInsets.only(top: 14), width: 40, height: 4,
            decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
          ),
          // Scrollable Content
          Expanded(child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Header Row
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Text("Create Post", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: colorScheme.onSurface)),
                  if (_feeling != null) FeelingDisplay(userName: name, feeling: _feeling!),
                ]),
                GestureDetector(onTap: () => Navigator.pop(context),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: colorScheme.onSurface.withValues(alpha: 0.07),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 0.5),
                  ), child: Icon(Icons.close_rounded, size: 18, color: colorScheme.onSurface)),
                ),
              ]),
              const SizedBox(height: 16),
              // User Row
              Row(children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colorScheme.primary, width: 2),
                  color: colorScheme.primaryContainer,
                ), child: hasAvatar
                    ? ClipRRect(borderRadius: BorderRadius.circular(13),
                        child: CachedNetworkImage(imageUrl: avatarUrl, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Center(child: Text(initials, style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 16)))))
                    : Center(child: Text(initials, style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 16)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  // Privacy badge
                  GestureDetector(
                    onTap: () => _showPrivacyPicker(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.4), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(privacyIcon(_privacy), size: 12, color: colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(privacyLabel(_privacy), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.primary)),
                        const SizedBox(width: 2),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: colorScheme.primary),
                      ]),
                    ),
                  ),
                ]),
              ]),
              const SizedBox(height: 12),
              // Privacy Selector
              PrivacySelector(selected: _privacy, onChanged: (p) => setState(() => _privacy = p)),
              const SizedBox(height: 16),
              // ========== Text Area with Mention Support (Modified) ==========
              Container(
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2), width: 1),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TextField(
                          controller: _textController,
                          maxLines: null,
                          minLines: 3,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's on your mind, ${name.split(' ').first}?",
                            hintStyle: TextStyle(
                              color: colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            _mentionController.onTextUpdated(val);
                            setState(() {});
                          },
                        ),
                        // Mention suggestions overlay
                        if (_mentionController.showingSuggestions)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: _mentionController.filteredSuggestions.length,
                                itemBuilder: (context, index) {
                                  final user = _mentionController.filteredSuggestions[index];
                                  final avatarUrl = (user.avatarUrl ?? '').trim();
                                  final hasAvatar = avatarUrl.isNotEmpty;
                                  final initials = user.name.trim().isNotEmpty
                                      ? user.name.trim()[0].toUpperCase()
                                      : 'U';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      radius: 16,
                                      backgroundImage: hasAvatar
                                          ? CachedNetworkImageProvider(avatarUrl)
                                          : null,
                                      child: hasAvatar
                                          ? null
                                          : Text(
                                              initials,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                    ),
                                    title: Text(
                                      user.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    subtitle: user.bio != null && user.bio!.isNotEmpty
                                        ? Text(
                                            user.bio!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                                            ),
                                          )
                                        : null,
                                    onTap: () {
                                      _mentionController.selectMention(user);
                                      setState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        "${postText.length}",
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ==============================================================
              // Media Previews
              if (selectedImagesBytes.isNotEmpty) _buildImagesPreview(),
              if (selectedVideoBytes != null) _buildVideoPreview(),
              const SizedBox(height: 16),
              // Media Buttons (Photo, Video, Feeling)
              Row(children: [
                _buildMediaButton(icon: Icons.image_rounded, label: "Photo", color: colorScheme.primary, onTap: _pickImages),
                const SizedBox(width: 8),
                _buildMediaButton(icon: Icons.videocam_rounded, label: "Video", color: colorScheme.secondary, onTap: _pickVideo),
                const SizedBox(width: 8),
                _buildMediaButton(
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  label: _feeling != null ? _feeling!.emoji : "Feeling",
                  color: colorScheme.tertiary,
                  onTap: () => _showFeelingPicker(),
                ),
              ]),
              Divider(color: colorScheme.outline.withValues(alpha: 0.15), height: 32, thickness: 1),
              // Chips row
              Wrap(spacing: 10, runSpacing: 10, children: [
                FeelingChipButton(selected: _feeling, onChanged: (f) => setState(() => _feeling = f)),
                _buildMentionChip(),
              ]),
              const SizedBox(height: 24),
              _buildPostButton(),
            ]),
          )),
        ]),
      ),
    );
  }

  void _showPrivacyPicker() {
    // The PrivacySelector is already shown inline, but tapping badge cycles through
    final values = PostPrivacy.values;
    final nextIndex = (values.indexOf(_privacy) + 1) % values.length;
    setState(() => _privacy = values[nextIndex]);
  }

  void _showFeelingPicker() {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: colorScheme.onSurface.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text("How are you feeling?", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
          const SizedBox(height: 16),
          Wrap(spacing: 10, runSpacing: 10, children: availableFeelings.map((feeling) {
            final isSelected = _feeling == feeling;
            return GestureDetector(
              onTap: () { setState(() => _feeling = isSelected ? null : feeling); Navigator.pop(ctx); },
              child: AnimatedContainer(duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary.withValues(alpha: 0.12) : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isSelected ? colorScheme.primary.withValues(alpha: 0.5) : colorScheme.outline.withValues(alpha: 0.15), width: isSelected ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(feeling.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  Text(feeling.label, style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? colorScheme.primary : colorScheme.onSurface)),
                ]),
              ),
            );
          }).toList()),
          if (_feeling != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () { setState(() => _feeling = null); Navigator.pop(ctx); },
              icon: Icon(Icons.clear_rounded, size: 16, color: colorScheme.error),
              label: Text("Remove feeling", style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildMentionChip() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () {
        // Insert @ at current cursor position
        final text = _textController.text;
        final pos = _textController.selection.baseOffset;
        final before = pos >= 0 ? text.substring(0, pos) : text;
        final after = pos >= 0 && pos < text.length ? text.substring(pos) : '';
        final needsSpace = before.isNotEmpty && before[before.length - 1] != ' ' && before[before.length - 1] != '\n';
        final insertion = '${needsSpace ? ' ' : ''}@';
        _textController.text = '$before$insertion$after';
        _textController.selection = TextSelection.collapsed(offset: before.length + insertion.length);
        _mentionController.onTextUpdated(_textController.text);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outline.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.alternate_email_rounded, color: colorScheme.primary, size: 16),
          const SizedBox(width: 6),
          Text("Mention", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface.withValues(alpha: 0.6))),
        ]),
      ),
    );
  }

  Widget _buildMediaButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(child: GestureDetector(onTap: onTap,
      child: CustomPaint(
        painter: DashedBorderPainter(color: colorScheme.outline.withValues(alpha: 0.2), borderRadius: 12, dashWidth: 4, dashSpace: 3),
        child: Container(height: 54, decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12),
        ), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20), const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis)),
        ])),
      ),
    ));
  }

  Widget _buildPostButton() {
    final postsProvider = context.watch<PostsProvider>();
    final canPost = postText.trim().isNotEmpty || selectedImagesBytes.isNotEmpty || selectedVideoBytes != null;
    return SizedBox(width: double.infinity, height: 44, child: ElevatedButton(
      onPressed: (!canPost || postsProvider.isCreatingPost) ? null : _submitPost,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
        disabledForegroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)), elevation: 0,
      ),
      child: postsProvider.isCreatingPost
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Post now", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              SizedBox(width: 8), Icon(Icons.send_rounded, size: 16),
            ]),
    ));
  }

  Widget _buildImagesPreview() {
    return Container(height: 180, width: double.infinity, margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: 1)),
      child: Stack(children: [
        PageView.builder(itemCount: selectedImagesBytes.length,
          onPageChanged: (i) => setState(() => previewIndex = i),
          itemBuilder: (context, i) => Stack(fit: StackFit.expand, children: [
            Image.memory(selectedImagesBytes[i], fit: BoxFit.cover),
            Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.3)],
            )))),
          ])),
        Positioned(top: 8, right: 8, child: GestureDetector(
          onTap: () => setState(() { selectedImagesBytes = []; previewIndex = 0; }),
          child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
            child: const Icon(Icons.close_rounded, color: Colors.white, size: 16)),
        )),
        if (selectedImagesBytes.length > 1) ...[
          Positioned(bottom: 10, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(selectedImagesBytes.length, (i) {
              final active = i == previewIndex;
              return AnimatedContainer(duration: const Duration(milliseconds: 160), margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 12 : 6, height: 6, decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: active ? 0.95 : 0.55), borderRadius: BorderRadius.circular(3)));
            }))),
          Positioned(top: 10, left: 10, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
            child: Text('${previewIndex + 1}/${selectedImagesBytes.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          )),
        ],
      ]),
    );
  }

  Widget _buildVideoPreview() {
    return Container(width: double.infinity, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(children: [
        Icon(Icons.smart_display_rounded, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text('Video selected', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSecondaryContainer))),
        GestureDetector(onTap: () => setState(() => selectedVideoBytes = null),
          child: Container(padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: 14, color: Theme.of(context).colorScheme.onSecondaryContainer)),
        ),
      ]),
    );
  }
}