import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';

class TextFieldContainer extends StatelessWidget {
  final Widget? child;
  TextFieldContainer({
    Key? key,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      width: context.width * 0.8,
      decoration: BoxDecoration(
        color: AppColors.AppBarColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
