import 'package:flutter/material.dart';

/// Design-token set for the Admin Dashboard screen.
///
/// Usage:
/// ```dart
/// final tok = AdminTokens.of(context);
/// Container(color: tok.bgSurface)
/// ```
///
/// All colors are resolved at call-site from the current [ThemeData] brightness,
/// so the screen re-renders automatically whenever [ThemeProvider] toggles the mode.
class AdminTokens {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  final Color bgPrimary;    // app scaffold bg
  final Color bgSurface;    // cards, stat tiles
  final Color bgHeader;     // sticky header bar

  // ── Borders ────────────────────────────────────────────────────────────────
  final Color borderDefault;

  // ── Text ───────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // ── Accents ────────────────────────────────────────────────────────────────
  final Color accentPrimary;   // blue — tabs, links, selection
  final Color accentMention;   // blue — mention card bar + chips
  final Color accentQuestion;  // amber — question card bar + quote border
  final Color accentSuccess;   // green — approve button
  final Color accentDanger;    // red   — reject button

  // ── Chip / Quote surfaces ──────────────────────────────────────────────────
  final Color mentionChipBg;   // light tint behind @mention pill
  final Color mentionChipText; // text inside @mention pill
  final Color quoteBg;         // background of the quoted-text block

  // ── Overlay helpers (for header search bar & tab pill) ─────────────────────
  final Color headerOverlay;   // semi-transparent white overlay on blue header
  final Color activeTabBg;     // solid bg for the active tab pill

  const AdminTokens._({
    required this.bgPrimary,
    required this.bgSurface,
    required this.bgHeader,
    required this.borderDefault,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentPrimary,
    required this.accentMention,
    required this.accentQuestion,
    required this.accentSuccess,
    required this.accentDanger,
    required this.mentionChipBg,
    required this.mentionChipText,
    required this.quoteBg,
    required this.headerOverlay,
    required this.activeTabBg,
  });

  // ── Light tokens ────────────────────────────────────────────────────────────
  factory AdminTokens.light() => const AdminTokens._(
        bgPrimary: Color(0xFFF5F6FA),
        bgSurface: Color(0xFFFFFFFF),
        bgHeader: Color(0xFF2F4EE0),
        borderDefault: Color(0xFFE4E6F0),
        textPrimary: Color(0xFF0A0E1F),
        textSecondary: Color(0xFF5D6494),
        textTertiary: Color(0xFF8A8FB0),
        accentPrimary: Color(0xFF2F4EE0),
        accentMention: Color(0xFF2F4EE0),
        accentQuestion: Color(0xFFF59E0B),
        accentSuccess: Color(0xFF10B981),
        accentDanger: Color(0xFFEF4444),
        mentionChipBg: Color(0xFFEEF1FD),
        mentionChipText: Color(0xFF2F4EE0),
        quoteBg: Color(0xFFFFFBF0),
        headerOverlay: Color(0x26FFFFFF), // 15% white
        activeTabBg: Color(0xFFFFFFFF),
      );

  // ── Dark tokens ─────────────────────────────────────────────────────────────
  factory AdminTokens.dark() => const AdminTokens._(
        bgPrimary: Color(0xFF0A0E1F),
        bgSurface: Color(0xFF101630),
        bgHeader: Color(0xFF2F4EE0),
        borderDefault: Color(0xFF1F2750),
        textPrimary: Color(0xFFFFFFFF),
        textSecondary: Color(0xFF7D84A8),
        textTertiary: Color(0xFF5D6494),
        accentPrimary: Color(0xFF2F4EE0),
        accentMention: Color(0xFF4D6BF5),
        accentQuestion: Color(0xFFF59E0B),
        accentSuccess: Color(0xFF10B981),
        accentDanger: Color(0xFFEF4444),
        mentionChipBg: Color(0xFF1A2354),
        mentionChipText: Color(0xFF7D9CF5),
        quoteBg: Color(0xFF1C1A0F),
        headerOverlay: Color(0x26FFFFFF), // 15% white
        activeTabBg: Color(0xFF101630),
      );

  /// Resolves the correct token set from the ambient [BuildContext].
  /// The result automatically tracks the app's current [ThemeMode].
  factory AdminTokens.of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AdminTokens.dark()
        : AdminTokens.light();
  }
}
