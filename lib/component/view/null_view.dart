import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user/user_view.dart';

class NullView extends StatelessWidget {
  String str;

  NullView({this.str = '无会话消息'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        child: Text(
          str,
          style: TextStyle(color: AppColors.MainTextColor),
        ),
        onTap: () => Get.to(UserPage()),
      ),
    );
  }
}
