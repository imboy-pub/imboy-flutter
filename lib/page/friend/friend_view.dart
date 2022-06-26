import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/search_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

class FriendPage extends StatelessWidget {
  // final AddFriendLogic logic = Get.put(AddFriendLogic());
  bool isSearch = false;
  bool showBtn = false;
  bool isResult = false;
  FocusNode searchF = new FocusNode();
  TextEditingController searchC = new TextEditingController();

  @override
  Widget build(BuildContext context) {
    Widget secondary = Text(
      "√",
      style: TextStyle(
        fontSize: 20,
        color: AppColors.primaryElement,
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '新的朋友'.tr,
        rightDMActions: [
          TextButton(
            onPressed: () {},
            child: Text(
              '添加朋友'.tr,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.ChatBg,
          child: n.Column([
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                top: 10,
                right: 8,
                bottom: 10,
              ),
              child: SearchBar(
                text: '微信号/手机号',
                isBorder: true,
                onTap: () {
                  isSearch = true;
                  // setState(() {});
                  searchF.requestFocus();
                },
              ),
            ),
            LabelRow(
              headW: new Padding(
                padding: EdgeInsets.only(right: 15.0),
                child: new Image.asset('assets/images/contact/ic_voice.png',
                    width: 25, fit: BoxFit.cover),
              ),
              label: '添加手机联系人',
            ),
            // n.ListTile(),
          ]),
        ),
      ),
    );
  }
}
