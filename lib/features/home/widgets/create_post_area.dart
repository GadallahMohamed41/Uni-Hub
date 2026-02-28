import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme.dart';
import '../../../providers/auth_provider.dart';

class CreatePostArea extends StatelessWidget {
  final VoidCallback onTapComposer;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapVideo;
  const CreatePostArea({super.key, required this.onTapComposer, required this.onTapPhoto, required this.onTapVideo});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2), width: 2),
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: user?.avatarUrl != null ? CachedNetworkImageProvider(user!.avatarUrl!) : null,
                  child: user?.avatarUrl == null ? const Icon(Icons.person, size: 24) : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: onTapComposer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(color: AppTheme.surfaceVariant, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, color: AppTheme.textSecondary, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "What's on your mind?",
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: TextStyle(fontWeight: FontWeight.w500, color: AppTheme.textSecondary, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppTheme.surfaceVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _actionIcon(Icons.article_rounded, "Article", const Color(0xFFE06847), onTapComposer)),
              Expanded(child: _actionIcon(Icons.photo_size_select_actual_rounded, "Photo", const Color(0xFF378FE9), onTapPhoto)),
              Expanded(child: _actionIcon(Icons.smart_display_rounded, "Video", const Color(0xFF5F9B41), onTapVideo)),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionIcon(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(color: AppTheme.textMain, fontWeight: FontWeight.w600, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

