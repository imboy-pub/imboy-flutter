import 'package:flutter/material.dart';
import 'package:get/get.dart';

const kPrimaryColor = Color(0xFFc44dff);

class RoundedButton extends StatelessWidget {
  final onPressed;
  final String text;
  final Color color, textColor;

  const RoundedButton(
      {Key key,
      this.onPressed,
      this.text,
      this.color = kPrimaryColor,
      this.textColor = Colors.white})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: Get.width * 0.8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: TextButton(
          //设置按钮是否自动获取焦点
          autofocus: true,
          style: ButtonStyle(
            //设置按钮内边距
            padding: MaterialStateProperty.all(EdgeInsets.all(16)),
            //背景颜色
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              //设置按下时的背景颜色
              if (states.contains(MaterialState.pressed)) {
                return Colors.blue[600];
              }
              //默认不使用背景颜色
              return Colors.blue[400];
            }),
          ),
          onPressed: onPressed,
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
