import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class EasyLoadingProgress extends StatelessWidget {
  const EasyLoadingProgress({
    super.key,
    required this.value,
    required this.color,
    required this.size,
    required this.width,
  });

  final double value;
  final Color color;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CirclePainter(color: color, value: value, width: width),
      ),
    );
  }
}

class _CirclePainter extends CustomPainter {
  const _CirclePainter({
    required this.color,
    required this.value,
    required this.width,
  });

  final Color color;
  final double value;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final rect = (Offset.zero & size).deflate(width / 2);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, paint);
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) {
    return value != oldDelegate.value ||
        color != oldDelegate.color ||
        width != oldDelegate.width;
  }
}
