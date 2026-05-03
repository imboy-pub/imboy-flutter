import 'dart:math';

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'clip_painter.dart';

class BezierContainer extends StatelessWidget {
  const BezierContainer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 暗色模式使用低透明度品牌色渐变，亮色模式保持原样
    final colors = isDark
        ? [
            AppColors.primary.withValues(alpha: 0.3),
            AppColors.primaryLight.withValues(alpha: 0.1),
          ]
        : [AppColors.primary, AppColors.primaryLight];

    return Transform.rotate(
      angle: -pi / 3.5,
      child: ClipPath(
        clipper: ClipPainter(),
        child: Container(
          height: MediaQuery.of(context).size.height * .5,
          width: MediaQuery.of(context).size.width,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}
