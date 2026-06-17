import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/features/chat/presentation/screens/conversations_screen.dart';
import 'package:project_test2/features/community/community_screen.dart';
import 'package:project_test2/features/home/home_screen.dart';
import 'package:project_test2/features/profile/profile_screen.dart';
import 'package:project_test2/features/connections/presentation/connections_screen.dart';
import 'package:project_test2/features/assistant/assistant_peek_button.dart';
import 'package:project_test2/services/push_notifications_service.dart';
import 'package:project_test2/core/i18n.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => MainLayoutState();
}

class MainLayoutState extends State<MainLayout>
    with TickerProviderStateMixin {
  static MainLayoutState? instance;

  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ConversationsScreen(),
    const CommunityScreen(),
    const ConnectionsScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    instance = this;

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutBack,
      ),
    );
    _slideController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationsService.instance.processDeferredLaunchData();
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void goToProfile() {
    _onItemTapped(4);
  }

  void _onItemTapped(int index) {
    if (_currentIndex == index) return;
    
    setState(() {
      _currentIndex = index;
    });

    // Smooth page transition
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
    
    // Beautiful bounce animation for nav bar
    _slideController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            children: _screens,
          ),
          bottomNavigationBar: SlideTransition(
            position: _slideAnimation,
            child: _buildCustomNavBar(),
          ),
        ),
        const AssistantPeekButton(),
      ],
    );
  }


  Widget _buildCustomNavBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      height: 68,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151E2E).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.4) : AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_rounded,
                  context.tr(en: "Home", ar: "الرئيسية")),
              _buildNavItem(1, Icons.chat_bubble_rounded,
                  context.tr(en: "Chats", ar: "الدردشات")),
              _buildNavItem(2, Icons.groups_rounded,
                  context.tr(en: "Groups", ar: "المجتمعات")),
              _buildNavItem(3, Icons.people_alt_rounded,
                  context.tr(en: "Network", ar: "المعارف")),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    
    return _AnimatedNavItem(
      isSelected: isSelected,
      icon: icon,
      label: label,
      onTap: () => _onItemTapped(index),
    );
  }
}

// Professional Animated Nav Item with beautiful animations
class _AnimatedNavItem extends StatefulWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AnimatedNavItem({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _iconScaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(_AnimatedNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) {
        _controller.reverse();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        _controller.forward().then((_) {
          _controller.reverse();
        });
        widget.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSelected 
              ? AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.scale(
                    scale: widget.isSelected ? _iconScaleAnimation.value : 1.0,
                    child: Icon(
                      widget.icon,
                      size: 24,
                      color: widget.isSelected
                          ? AppTheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: SizedBox(
                      height: widget.isSelected ? null : 0,
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
