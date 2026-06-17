import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/app_snackbar.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/posts_provider.dart';

class CreatePostSheet extends StatefulWidget {
  final List<Uint8List>? initialImages;
  final Uint8List? initialVideo;

  const CreatePostSheet({
    super.key,
    this.initialImages,
    this.initialVideo,
  });

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<CreatePostSheet> {
  final ImagePicker _picker = ImagePicker();
  String postText = "";
  List<Uint8List> selectedImagesBytes = [];
  Uint8List? selectedVideoBytes;
  int previewIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null) {
      selectedImagesBytes = List.from(widget.initialImages!);
    }
    if (widget.initialVideo != null) {
      selectedVideoBytes = widget.initialVideo;
    }
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) return;
      final bytesList = <Uint8List>[];
      for (final img in images) {
        bytesList.add(await img.readAsBytes());
      }
      setState(() {
        selectedImagesBytes = bytesList;
        previewIndex = 0;
        selectedVideoBytes = null;
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Failed to pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final bytes = await video.readAsBytes();
      setState(() {
        selectedVideoBytes = bytes;
        selectedImagesBytes = [];
      });
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.showError(context, 'Failed to pick video: $e');
    }
  }

  Future<void> _submitPost() async {
    final authProvider = context.read<AuthProvider>();
    final postsProvider = context.read<PostsProvider>();
    final user = authProvider.currentUser;

    if (user == null) {
      AppSnackBar.showError(context, 'You must be logged in to post');
      return;
    }

    if (user.isBlocked) {
      if (user.blockedUntil != null && user.blockedUntil!.isAfter(DateTime.now())) {
        AppSnackBar.showError(
          context,
          'You are blocked from posting until ${user.blockedUntil.toString().split('.')[0]}',
        );
        return;
      } else if (user.blockedUntil == null) {
        AppSnackBar.showError(context, 'You are permanently blocked from posting');
        return;
      }
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
    );

    if (!mounted) return;
    if (success) {
      Navigator.pop(context);
      if (!user.isAdmin) {
        AppSnackBar.showInfo(context, 'Post submitted for approval');
      }
    } else {
      final msg = postsProvider.error ?? 'Failed to create post';
      AppSnackBar.showError(context, msg);
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
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Container(
        height: sheetHeight,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: ui.Radius.circular(28)),
        ),
        child: Column(
          children: [
            // ─── Top Glow Line ───────────────────────────────────────────────
            Container(
              height: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: ui.Radius.circular(28)),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.1),
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),

            // ─── Handle Bar ──────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.only(top: 14),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ─── Scrollable Content ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Header Row ──────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Create Post",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: colorScheme.onSurface.withValues(alpha: 0.07),
                              border: Border.all(
                                color: colorScheme.outline.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── User Row ────────────────────────────────────────────
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 2,
                            ),
                            color: colorScheme.primaryContainer,
                          ),
                          child: hasAvatar
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: CachedNetworkImage(
                                    imageUrl: avatarUrl,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => Center(
                                      child: Text(
                                        initials,
                                        style: TextStyle(
                                          color: colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials,
                                    style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.primary.withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public_rounded,
                                    size: 12,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Everyone",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 14,
                                    color: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ─── Text Area ───────────────────────────────────────────
                    Container(
                      constraints: const BoxConstraints(minHeight: 120),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: colorScheme.outline.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
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
                              setState(() {
                                postText = val;
                              });
                            },
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

                    // Media Previews
                    if (selectedImagesBytes.isNotEmpty) _buildImagesPreview(),
                    if (selectedVideoBytes != null) _buildVideoPreview(),

                    const SizedBox(height: 16),

                    // ─── Media Buttons (2 columns) ───────────────────────────
                    Row(
                      children: [
                        _buildMediaButton(
                          icon: Icons.image_rounded,
                          label: "Photo",
                          color: colorScheme.primary,
                          onTap: _pickImages,
                        ),
                        const SizedBox(width: 12),
                        _buildMediaButton(
                          icon: Icons.videocam_rounded,
                          label: "Video",
                          color: colorScheme.secondary,
                          onTap: _pickVideo,
                        ),
                      ],
                    ),

                    // ─── Separator ───────────────────────────────────────────
                    Divider(
                      color: colorScheme.outline.withValues(alpha: 0.15),
                      height: 32,
                      thickness: 1,
                    ),

                    // ─── Chips (Feeling + Mention) ───────────────────────────
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildActionChip(
                          icon: Icons.sentiment_satisfied_alt_rounded,
                          label: "Feeling",
                          iconColor: colorScheme.tertiary,
                          onTap: () {
                            AppSnackBar.showInfo(context, 'Feeling selected (Demo)');
                          },
                        ),
                        _buildActionChip(
                          icon: Icons.alternate_email_rounded,
                          label: "Mention",
                          iconColor: colorScheme.primary,
                          onTap: () {
                            AppSnackBar.showInfo(context, 'Mention tag activated (Demo)');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ─── Post Button ──────────────────────────────────────────
                    _buildPostButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: DashedBorderPainter(
            color: colorScheme.outline.withValues(alpha: 0.2),
            borderRadius: 12,
            dashWidth: 4,
            dashSpace: 3,
          ),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostButton() {
    final postsProvider = context.watch<PostsProvider>();
    final canPost = postText.trim().isNotEmpty ||
        selectedImagesBytes.isNotEmpty ||
        selectedVideoBytes != null;

    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: (!canPost || postsProvider.isCreatingPost) ? null : _submitPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          disabledForegroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          elevation: 0,
        ),
        child: postsProvider.isCreatingPost
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "Post now",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.send_rounded, size: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildImagesPreview() {
    return Container(
      height: 180,
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          PageView.builder(
            itemCount: selectedImagesBytes.length,
            onPageChanged: (i) => setState(() => previewIndex = i),
            itemBuilder: (context, i) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    selectedImagesBytes[i],
                    fit: BoxFit.cover,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                selectedImagesBytes = [];
                previewIndex = 0;
              }),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          if (selectedImagesBytes.length > 1) ...[
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(selectedImagesBytes.length, (i) {
                  final active = i == previewIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 12 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: active ? 0.95 : 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${previewIndex + 1}/${selectedImagesBytes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_display_rounded,
            color: Theme.of(context).colorScheme.secondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Video selected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              selectedVideoBytes = null;
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = Path();

    double distance = 0.0;
    for (ui.PathMetric measurePath in path.computeMetrics()) {
      while (distance < measurePath.length) {
        dashPath.addPath(
          measurePath.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
