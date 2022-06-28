import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/search_bar.dart';
import 'package:imboy/component/view/nodata_view.dart';
import 'package:imboy/component/view/null_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/new_friend_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'new_friend_logic.dart';

class NewFriendPage extends StatelessWidget {
  final NewFriendLogic logic = Get.put(NewFriendLogic());
  bool isSearch = false;
  bool showBtn = false;
  bool isResult = false;
  @override
  Widget build(BuildContext context) {
    logic.items.value = [];
    logic.items.value.add(NewFriendModel(
      from: "",
      to: "",
      avatar: defAvatar,
      nickname: 'nickname',
      msg: '我：我是程老师介绍的李源炳顶顶顶顶顶顶顶',
      payload: {},
      createTime: 1,
    ));
    logic.items.value.add(NewFriendModel(
      from: UserRepoLocal.to.currentUid,
      to: "",
      avatar: defAvatar,
      nickname: 'nickname',
      msg: '我：我是程老师介绍的李源炳顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶顶的',
      payload: {},
      createTime: 1,
    ));
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
          child: n.Column(
            [
              Padding(
                padding: const EdgeInsets.only(
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
                    logic.searchF.requestFocus();
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: LabelRow(
                  headW: Padding(
                    padding: const EdgeInsets.only(right: 15.0),
                    child: Image.asset(
                      'assets/images/contact/ic_voice.png',
                      width: 25,
                      fit: BoxFit.cover,
                    ),
                  ),
                  label: '添加手机联系人',
                ),
              ),
              // Spacer(),
              Expanded(
                child: Obx(() {
                  return logic.items.isEmpty
                      ? NoDataView(
                          str: '没有新的好友'.tr,
                        )
                      : ListView.builder(
                          itemBuilder: (BuildContext context, int index) {
                            NewFriendModel model = logic.items.value[index];
                            List<Widget> rightWidget = [];
                            if (model.from == UserRepoLocal.to.currentUid) {
                              rightWidget.add(
                                const Icon(Icons.turn_slight_right),
                              );
                            }
                            rightWidget.add(Text('等待验证'.tr));
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  bottom: BorderSide(
                                    width: 0.2,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              child: n.ListTile(
                                leading: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(4.0),
                                    color: Color(0xFFE5E5E5),
                                    image: dynamicAvatar(model.avatar),
                                  ),
                                ),
                                title: Text(model.nickname),
                                subtitle: Text(model.msg),
                                trailing: Container(
                                  width: 80,
                                  alignment: Alignment.centerRight,
                                  child: n.Row(rightWidget),
                                ),
                              ),
                            );
                          },
                          itemCount: logic.items.length,
                        );
                }),
              ),
            ],
            mainAxisSize: MainAxisSize.min,
          ),
        ),
      ),
    );
  }
}
