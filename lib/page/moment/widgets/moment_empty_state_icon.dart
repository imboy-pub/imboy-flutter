import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 呼吸缩放图标：3 秒循环 1.0↔1.05，用于空状态让画面不"死"。
class MomentEmptyStateIcon extends StatefulWidget {
  final IconData icon;
  final double size;

  const MomentEmptyStateIcon({
    super.key,
    required this.icon,
    required this.size,
  });

  @override
  State<MomentEmptyStateIcon> createState() => _MomentEmptyStateIconState();
}

class _MomentEmptyStateIconState extends State<MomentEmptyStateIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Icon(
        widget.icon,
        size: widget.size,
        color: AppColors.iosGray.withValues(alpha: 0.3),
      ),
    );
  }
}
