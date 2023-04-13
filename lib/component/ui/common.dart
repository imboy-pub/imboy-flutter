import 'dart:ui';

import 'package:flutter/material.dart';

class Space extends StatelessWidget {
  final double width;
  final double height;

  const Space({
    Key? key,
    this.width = 10.0,
    this.height = 10.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height);
  }
}

double topBarHeight(BuildContext context) {
  return kToolbarHeight + MediaQueryData.fromWindow(window).padding.top;
}
