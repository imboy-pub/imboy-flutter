import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/component/ui/shimmer_box.dart';

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final EdgeInsetsGeometry? padding;

  const ShimmerList({
    super.key,
    this.itemCount = 10,
    this.itemHeight = 72.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Use slightly lighter/darker shades for shimmer based on brightness
    final baseColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );
    final highlightColor = colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.2,
    );

    return ListView.builder(
      itemCount: itemCount,
      padding: padding ?? const EdgeInsets.all(0),
      physics:
          const NeverScrollableScrollPhysics(), // Disable scrolling while loading
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ShimmerBox(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar placeholder
                Container(
                  width: 48.0,
                  height: 48.0,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Name placeholder
                      Container(
                        width: double.infinity,
                        height: 16.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.borderRadiusTiny,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      // Subtitle placeholder
                      Container(
                        width: 150.0,
                        height: 12.0,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppRadius.borderRadiusTiny,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
