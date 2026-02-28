import 'package:flutter/material.dart';
import 'theme.dart';

class AppSnackBar {
  static void showError(BuildContext context, String message) {
    _show(context, message: message, backgroundColor: AppTheme.error, icon: Icons.error_outline_rounded);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message: message, backgroundColor: AppTheme.success, icon: Icons.check_circle_outline_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message: message, backgroundColor: AppTheme.info, icon: Icons.info_outline_rounded);
  }

  static void _show(
    BuildContext context, {
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: backgroundColor,
        showCloseIcon: true,
        closeIconColor: Colors.white.withOpacity(0.9),
        duration: const Duration(seconds: 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

