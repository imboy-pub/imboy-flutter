import 'package:flutter/widgets.dart';

/// 水平线
class HorizontalLine extends StatelessWidget {
  final double height;
  final Color color;
  final double horizontal;

  const HorizontalLine({
    Key? key,
    this.height = 0.5,
    this.color = const Color(0xFFEEEEEE),
    this.horizontal = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color,
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
    Key? key,
    this.width = 1.0,
    this.height = 25,
    this.color = const Color.fromRGBO(209, 209, 209, 0.5),
    this.vertical = 0.0,
  }) : super(key: key);

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
