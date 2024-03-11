import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// 水平线
class HorizontalLine extends StatelessWidget {
  final double height;
  final Color? color;
  final double horizontal;

  const HorizontalLine({
    super.key,
    this.height = 0.5,
    // this.color = const Color(0xFFEEEEEE),
    this.color,
    this.horizontal = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ??
          (Get.isDarkMode
              ? const Color.fromRGBO(100, 100, 100, 1)
              : const Color.fromRGBO(210, 210, 210, 1)),
      margin: EdgeInsets.symmetric(horizontal: horizontal),
    );
  }
}

/// 垂直线
class VerticalLine extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double vertical;

  const VerticalLine({
    super.key,
    this.width = 1.0,
    this.height = 25,
    this.color = const Color.fromRGBO(209, 209, 209, 0.5),
    this.vertical = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: const Color(0xffDCE0E5),
      margin: EdgeInsets.symmetric(vertical: vertical),
      height: height,
    );
  }
}
