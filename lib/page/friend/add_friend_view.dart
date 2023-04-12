import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/search_bar.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'add_friend_logic.dart';
import 'new_friend_logic.dart';

// ignore: must_be_immutable
class AddFriendPage extends StatelessWidget {

  bool isSearch = false;
  final AddFriendLogic logic = Get.put(AddFriendLogic());
  
  AddFriendPage({Key? key}) : super(key: key);

  
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(
        title: '添加朋友'.tr,
        // backgroundColor: AppColors.AppBarColor,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.AppBarColor,
          child: n.Column([
              n.Padding(
                left: 8,
                top: 10,
                right: 8,
                bottom: 10,
                child: SearchBar(
                  text: '微信号/手机号',
                  isBorder: true,
                  onTap: () {
                    isSearch = true;
                    Get.find<NewFriendLogic>().searchF.requestFocus();
                  },
                ),
              ),
          ])
        ),
      ),
    );
  }
}
