import 'package:flutter/material.dart';

class Space extends StatelessWidget {
  final double width;
  final double height;

  const Space({
    super.key,
    this.width = 10.0,
    this.height = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}
