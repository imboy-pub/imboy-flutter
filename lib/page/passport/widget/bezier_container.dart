import 'dart:math';

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'clip_painter.dart';

class BezierContainer extends StatelessWidget {
  const BezierContainer({super.key});

  @override
  Widget build(BuildContext context) {
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
              colors: [AppColors.primaryGreen, AppColors.primaryGreenLight],
            ),
          ),
        ),
      ),
    );
  }
}
