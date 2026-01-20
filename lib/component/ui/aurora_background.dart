import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Richer, slightly darker base for "Premium" feel
    // Using a very subtle off-white/greyish green tint as base
    const baseColor = Color(0xFFF5F9F6);

    return Stack(
      children: [
        // Base
        Container(color: baseColor),

        // Deep Anchor Orb (Bottom Left) - Adds weight
        Positioned(
          bottom: -100,
          left: -50,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2), // Deep Primary
                  Colors.transparent,
                ],
              ),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
              child: const SizedBox(),
            ),
          ),
        ),

        // Moving Orb 1: Vibrant Teal (Top Left moving Down-Right)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: -100 + (_controller.value * 100),
              left: -50 + (_controller.value * 50),
              child: Container(
                width: 450,
                height: 450,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.tealAccent.withValues(alpha: 0.25),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                  child: const SizedBox(),
                ),
              ),
            );
          },
        ),

        // Moving Orb 2: Soft Blue-Green (Center Right moving Up-Left)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: 300 - (_controller.value * 150),
              right: -100 - (_controller.value * 50),
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFF4DB6AC,
                  ).withValues(alpha: 0.2), // Soft Teal
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: const SizedBox(),
                ),
              ),
            );
          },
        ),

        // Moving Orb 3: Highlight Green (Top Center)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              top: -150,
              left: 100 + (_controller.value * 100),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                  child: const SizedBox(),
                ),
              ),
            );
          },
        ),

        // Noise Overlay (Simulated with a grainy gradient or just keep it clean)
        // For performance and simplicity, we'll keep it clean but add a global whitewash
        // to unify the colors.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), // Global mesh blur
          child: Container(color: Colors.white.withValues(alpha: 0.2)),
        ),
      ],
    );
  }
}
