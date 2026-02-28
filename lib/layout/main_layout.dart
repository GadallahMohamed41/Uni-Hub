import 'package:flutter/material.dart';
import 'package:project_test2/core/theme.dart';
import 'package:project_test2/features/chat/chat_screen.dart';
import 'package:project_test2/features/community/community_screen.dart';
import 'package:project_test2/features/home/home_screen.dart';
import 'package:project_test2/features/profile/profile_screen.dart';
import 'package:project_test2/widgets/assistant_floating_button.dart';


class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  final List<Widget> _screens = [
    const HomeScreen(),
    const ChatScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pageController.dispose();
    super.dispose();
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
        const DraggableFloatingButton(),
      ],
    );
  }

  Widget _buildCustomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_rounded, "Home"),
          _buildNavItem(1, Icons.chat_bubble_rounded, "Chats"),
          _buildNavItem(2, Icons.groups_rounded, "Community"),
          _buildNavItem(3, Icons.person_rounded, "Profile"),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;
    // Shorten labels to prevent overflow
    String displayLabel = label;
    if (label == "Community") {
      displayLabel = "Comm";
    } else if (label.length > 6) {
      displayLabel = label.substring(0, 6);
    }

    return Expanded(
      child: _AnimatedNavItem(
        isSelected: isSelected,
        icon: icon,
        label: displayLabel,
        onTap: () => _onItemTapped(index),
      ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _controller.forward().then((_) {
            _controller.reverse();
          });
          widget.onTap();
        },
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: widget.isSelected ? 8 : 4,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            gradient: widget.isSelected ? AppTheme.primaryGradient : null,
            color: widget.isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: widget.isSelected ? _iconScaleAnimation.value : 1.0,
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: widget.isSelected
                            ? Colors.white
                            : AppTheme.textTertiary,
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: SizedBox(
                        width: widget.isSelected ? null : 0,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              color: widget.isSelected
                                  ? Colors.white
                                  : AppTheme.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}