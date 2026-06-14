import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// Shimmer loading placeholder — replaces package:shimmer.
///
/// Usage:
/// ```dart
/// ShimmerBox(
///   baseColor: Colors.grey[300]!,
///   highlightColor: Colors.grey[100]!,
///   child: Container(color: Colors.white, width: 120, height: 80),
/// )
/// ```
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.child,
    this.baseColor = AppColors.shimmerBase,
    this.highlightColor = AppColors.shimmerHighlight,
  });

  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
          ).createShader(bounds),
          blendMode: BlendMode.srcIn,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
