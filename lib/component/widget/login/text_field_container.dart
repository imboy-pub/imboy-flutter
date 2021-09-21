import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/helper/constant.dart';

class TextFieldContainer extends StatelessWidget {
  final Widget? child;
  TextFieldContainer({
    Key? key,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      width: context.width * 0.8,
      decoration: BoxDecoration(
        color: Color(AppColors.AppBarColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
