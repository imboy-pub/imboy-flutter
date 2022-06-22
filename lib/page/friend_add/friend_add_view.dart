import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/icon_text.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/component/ui/title_text_field.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

import 'friend_add_logic.dart';
import 'friend_add_state.dart';

class FriendAddPage extends StatelessWidget {
  String uid;
  String remark;

  FriendAddPage(
    this.uid,
    this.remark,
  );

  final FriendAddLogic logic = Get.put(FriendAddLogic());
  final FriendAddState state = Get.find<FriendAddLogic>().state;
  TextEditingController _msgController = TextEditingController();
  TextEditingController _remarkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    _msgController.text = "我是".tr + " " + UserRepoLocal.to.currentUser.nickname;
    _remarkController.text = this.remark == null ? "" : this.remark;
    // logic.role = "1".obs;

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
        title: '申请添加朋友'.tr,
        backgroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: Get.width * 0.5,
          height: 40, // 宽度值必须设置为double.infinity
          child: ElevatedButton(
            onPressed: () async {},
            child: Text(
              '发送'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                AppColors.primaryElement,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                Colors.white,
              ),
              minimumSize: MaterialStateProperty.all(Size(60, 40)),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(EdgeInsets.zero),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.BgColor,
          child: Padding(
            padding: EdgeInsets.only(
              left: 30,
              top: 10,
              right: 30,
            ),
            child: n.Column(
              [
                TitleTextField(
                  title: '发送添加朋友申请'.tr,
                  controller: _msgController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 100,
                  contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                ),
                TitleTextField(
                  title: '设置备注'.tr,
                  controller: _remarkController,
                  minLines: 1,
                  maxLines: 1,
                  maxLength: 40,
                  contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                ),
                Text('标签'.tr),
                IconTextView(
                  leftText: '添加标签'.tr,
                  paddingLeft: 10,
                  onPressed: () {
                    Get.snackbar('Tips', '功能在开发者，请稍等');
                  },
                  decoration: ShapeDecoration(
                    color: Color.fromARGB(255, 247, 247, 247),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusDirectional.circular(5),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: 14,
                  ),
                  child: Text('设置朋友圈'.tr),
                ),
                Card(
                  color: Color.fromARGB(255, 247, 247, 247),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusDirectional.circular(5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Obx(
                    () => n.Column(
                      [
                        IMBoyRadioListTile(
                          value: "1",
                          title: n.Text("聊天、朋友圈、运动数据等".tr),
                          selected: false,
                          secondary: logic.role.value == "1" ? secondary : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primaryElement,
                          groupValue: logic.role.value,
                          contentPadding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                          onChanged: (val) {
                            logic.setRole(val.toString());
                          },
                        ),
                        IMBoyRadioListTile(
                          value: "2",
                          title: n.Text("仅聊天".tr),
                          selected: false,
                          secondary: logic.role.value == "2" ? secondary : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primaryElement,
                          groupValue: logic.role.value,
                          contentPadding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                          onChanged: (val) {
                            logic.setRole(val.toString());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Obx(
                  () => Padding(
                    padding: EdgeInsets.only(
                      top: 10,
                    ),
                    child: n.Column(
                      [
                        Text('朋友圈和状态'.tr),
                        Card(
                            color: Color.fromARGB(255, 247, 247, 247),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadiusDirectional.circular(5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: n.Column(
                              [
                                SwitchListTile(
                                  title: Text('不让他（她）看'),
                                  value: false,
                                  onChanged: (val) {
                                    logic.setRole(val.toString());
                                  },
                                ),
                                SwitchListTile(
                                  title: Text('不看他（她）'),
                                  value: false,
                                  onChanged: (val) {
                                    logic.setRole(val.toString());
                                  },
                                ),
                              ],
                            ))
                      ],
                      crossAxisAlignment: CrossAxisAlignment.start,
                    ),
                  ),
                ),
              ],
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
            ),
          ),
        ),
      ),
    );
  }
}
