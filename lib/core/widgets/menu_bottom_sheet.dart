import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:project_test2/core/theme/theme.dart';
import 'package:project_test2/core/providers/locale_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API – call this to show the menu overlay from anywhere.
// ─────────────────────────────────────────────────────────────────────────────

void showMenuOverlay(BuildContext context) {
  // Explicitly capture the LocaleProvider before the modal opens,
  // then pass it into the sheet context so Provider.of() works inside.
  final localeProvider = context.read<LocaleProvider>();
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (sheetCtx) => ChangeNotifierProvider<LocaleProvider>.value(
      value: localeProvider,
      child: const _MenuBottomSheetContent(),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal content widget
// ─────────────────────────────────────────────────────────────────────────────

class _MenuBottomSheetContent extends StatefulWidget {
  const _MenuBottomSheetContent();

  @override
  State<_MenuBottomSheetContent> createState() =>
      _MenuBottomSheetContentState();
}

class _MenuBottomSheetContentState extends State<_MenuBottomSheetContent>
    with SingleTickerProviderStateMixin {
  // Animation controller for the language toggle icon
  late AnimationController _langAnim;

  @override
  void initState() {
    super.initState();
    _langAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
  }

  @override
  void dispose() {
    _langAnim.dispose();
    super.dispose();
  }

  void _onLanguageTap() {
    _langAnim.forward(from: 0);
    context.read<LocaleProvider>().toggleLocale();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final localeProvider = context.watch<LocaleProvider>();
    final isArabic = localeProvider.isArabic;

    return Container(
      // Drag handle area + sheet
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag Handle ──────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Main Floating Card ───────────────────────────────────────────
          Flexible(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFFAFAFF),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : AppTheme.primary.withValues(alpha: 0.06),
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header Row ─────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // (a) Circular soft-blue icon container
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.filter_list_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),

                      const SizedBox(width: 10),

                      // (c) Language Toggle — solid, always visible
                      GestureDetector(
                        onTap: _onLanguageTap,
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isArabic
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: const Color(0xFF2563EB),
                              width: 1.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.language_rounded,
                                size: 16,
                                color: isArabic
                                    ? Colors.white
                                    : const Color(0xFF2563EB),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isArabic ? 'EN' : 'ع',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isArabic
                                      ? Colors.white
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // (e) Title text
                      Text(
                        isArabic ? 'القائمة' : 'Menu',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Menu Items List ────────────────────────────────────
                  _menuItems(context, isArabic, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItems(BuildContext context, bool isArabic, bool isDark) {
    final items = [
      _MenuItemData(
        icon: Icons.admin_panel_settings_rounded,
        title: isArabic ? 'لوحة الإدارة' : 'Admin Dashboard',
        iconColor: const Color(0xFFEF4444),
        onTap: () {},
      ),
      _MenuItemData(
        icon: Icons.person_rounded,
        title: isArabic ? 'تعديل الملف الشخصي' : 'Edit Profile',
        iconColor: const Color(0xFF3B82F6),
        onTap: () {},
      ),
      _MenuItemData(
        icon: Icons.lock_rounded,
        title: isArabic ? 'الخصوصية والأمان' : 'Privacy & Security',
        iconColor: const Color(0xFF10B981),
        onTap: () {},
      ),
      _MenuItemData(
        icon: Icons.repeat_rounded,
        title: isArabic ? 'إعادة النشر' : 'Reposts',
        iconColor: const Color(0xFF6366F1),
        onTap: () {},
      ),
      _MenuItemData(
        icon: Icons.description_rounded,
        title: isArabic ? 'سيرتي الذاتية' : 'My CV',
        iconColor: const Color(0xFF0EA5E9),
        onTap: () {},
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length, (i) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomMenuItem(
              icon: items[i].icon,
              title: items[i].title,
              iconColor: items[i].iconColor,
              isDark: isDark,
              onTap: () {
                Navigator.pop(context);
                items[i].onTap();
              },
            ),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Public Reusable Widget: CustomMenuItem
// ─────────────────────────────────────────────────────────────────────────────

class CustomMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? trailingWidget;

  const CustomMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
    this.subtitle,
    this.trailingWidget,
  });

  @override
  State<CustomMenuItem> createState() => _CustomMenuItemState();
}

class _CustomMenuItemState extends State<CustomMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressAnim;
  late Animation<double> _scaleAnim;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressAnim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _pressAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _pressAnim.forward();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _pressAnim.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _pressAnim.reverse();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed
                ? widget.iconColor.withValues(alpha: 0.05)
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.white),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isPressed
                  ? widget.iconColor.withValues(alpha: 0.2)
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04)),
              width: 1,
            ),
            boxShadow: _isPressed
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: widget.isDark ? 0.1 : 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Leading: icon in tinted soft background
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  widget.icon,
                  color: widget.iconColor,
                  size: 22,
                ),
              ),

              const SizedBox(width: 14),

              // Title + optional subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Trailing: chevron or custom widget
              widget.trailingWidget ??
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model (private)
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemData {
  final IconData icon;
  final String title;
  final Color iconColor;
  final VoidCallback onTap;

  const _MenuItemData({
    required this.icon,
    required this.title,
    required this.iconColor,
    required this.onTap,
  });
}
