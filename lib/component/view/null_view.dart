import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user/user_view.dart';

class ConversationNullView extends StatelessWidget {
  final String str;

  ConversationNullView({this.str = '无会话消息'});

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new InkWell(
        child: new Text(
          str,
          style: TextStyle(color: AppColors.MainTextColor),
        ),
        onTap: () => Get.to(new UserPage()),
      ),
    );
  }
}
