import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/user/user_view.dart';

class HomeNullView extends StatelessWidget {
  final String str;

  HomeNullView({this.str = '无会话消息'});

  @override
  Widget build(BuildContext context) {
    return new Center(
      child: new InkWell(
        child: new Text(
          str,
          style: TextStyle(color: mainTextColor),
        ),
        onTap: () => Get.to(new UserPage()),
      ),
    );
  }
}
