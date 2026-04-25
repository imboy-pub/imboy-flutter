import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

class GlassBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<GlassBottomBarItem> items;
  final double height;
  final double blur;

  const GlassBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 76.0,
    this.blur = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Background color with opacity for glass effect
    final backgroundColor = isDark
        ? AppColors.darkSurfaceContainer.withValues(alpha: 0.75)
        : AppColors.lightSurfaceContainerLow.withValues(alpha: 0.85); // WeChat style grey

    // Border color to "catch the light"
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.white.withValues(alpha: 0.5);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          height: height + MediaQuery.of(context).padding.bottom,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom
                : 6, // Reduced padding for devices with no safe area
            top: 6, // Reduced top padding
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(top: BorderSide(color: borderColor, width: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isSelected = currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Icon Container
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.all(
                          isSelected ? 6 : 4,
                        ), // Reduced from 8
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: AppRadius.borderRadiusLarge,
                        ),
                        child: item.iconBuilder != null
                            ? item.iconBuilder!(isSelected)
                            : Icon(
                                isSelected
                                    ? (item.activeIcon ?? item.icon)
                                    : item.icon,
                                color: isSelected
                                    ? AppColors.primary
                                    : theme.colorScheme.onSurface.withValues(
                                        alpha: 0.5,
                                      ),
                                size: 24, // Reduced from 26 -> 24
                              ),
                      ),
                      const SizedBox(height: 1), // Reduced from 2 -> 1
                      // Label
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10, // Reduced from 11 -> 10
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class GlassBottomBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  // Optional: Custom builder for complex icons (like Badges)
  // function(bool isSelected)
  final Widget Function(bool)? iconBuilder;

  GlassBottomBarItem({
    required this.icon,
    required this.label,
    this.activeIcon,
    this.iconBuilder,
  });
}
