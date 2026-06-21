import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

/// Group avatar with gradient fallback showing first letter.
class GroupAvatar extends StatelessWidget {
  final String? imageUrl;
  final String groupName;
  final double radius;

  const GroupAvatar({
    super.key,
    this.imageUrl,
    required this.groupName,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: _colorFor(groupName),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _fallback(),
          ),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _colorFor(groupName),
      child: Text(
        groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  static Color _colorFor(String name) {
    if (name.isEmpty) return AppTheme.primary;
    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.accent,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.info,
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
    ];
    int hash = 0;
    for (final ch in name.codeUnits) {
      hash = (hash * 31 + ch) & 0xFFFFFFFF;
    }
    return colors[hash % colors.length];
  }
}

