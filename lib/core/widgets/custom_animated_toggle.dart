import 'package:flutter/material.dart';

class CustomAnimatedToggle extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final IconData leftIcon;
  final IconData rightIcon;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  final Color? activeColor;
  final Color? inactiveColor;
  final Color? backgroundColor;
  final Color? activeBgColor;
  final Color? borderColor;

  const CustomAnimatedToggle({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftIcon,
    required this.rightIcon,
    required this.selectedIndex,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.backgroundColor,
    this.activeBgColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    const double height = 50.0;
    
    // Colors based on the provided image design or custom passed
    final Color cActiveColor = activeColor ?? const Color(0xFF00D2D3); 
    final Color cInactiveColor = inactiveColor ?? const Color(0xFF4A5568); 
    final Color cBackgroundColor = backgroundColor ?? const Color(0xFF0B101A); 
    final Color cActiveBgColor = activeBgColor ?? const Color(0xFF0D1E26); 
    final Color cBorderColor = borderColor ?? const Color(0xFF1E293B); 

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cBorderColor, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double halfWidth = constraints.maxWidth / 2;

          return Stack(
            children: [
              // Active pill background with animation
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                top: 0,
                bottom: 0,
                left: selectedIndex == 0 ? 0 : halfWidth,
                width: halfWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: cActiveBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cActiveColor, width: 1.5),
                  ),
                ),
              ),

              // Labels and Icons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(0),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              leftIcon,
                              size: 18,
                              color: selectedIndex == 0 ? cActiveColor : cInactiveColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              leftLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: selectedIndex == 0 ? cActiveColor : cInactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onChanged(1),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              rightIcon,
                              size: 18,
                              color: selectedIndex == 1 ? cActiveColor : cInactiveColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              rightLabel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                                color: selectedIndex == 1 ? cActiveColor : cInactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
