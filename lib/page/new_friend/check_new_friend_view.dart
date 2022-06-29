import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/icon_text.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/component/ui/title_text_field.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

import 'check_new_friend_logic.dart';

// ignore: must_be_immutable
class CheckNewFriendPage extends StatelessWidget {
  final CheckNewFriendLogic logic = Get.put(CheckNewFriendLogic());

  final TextEditingController _remarkController = TextEditingController();

  final String uid;
  final String msg;
  final String nickname;

  CheckNewFriendPage({
    Key? key,
    required this.uid,
    required this.msg,
    required this.nickname,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _remarkController.text = nickname;

    Widget secondary = const Text(
      "√",
      style: TextStyle(
        fontSize: 20,
        color: AppColors.primaryElement,
      ),
    );
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '通过朋友验证'.tr,
        backgroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: SizedBox(
          width: Get.width * 0.5,
          height: 40, // 宽度值必须设置为double.infinity
          child: ElevatedButton(
            onPressed: () async {},
            child: Text(
              '完成'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                AppColors.primaryElement,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                Colors.white,
              ),
              minimumSize: MaterialStateProperty.all(const Size(40, 40)),
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
            padding: const EdgeInsets.only(
              left: 30,
              top: 10,
              right: 30,
            ),
            child: Obx(
              () => n.Column(
                [
                  TitleTextField(
                    title: '设置备注'.tr,
                    controller: _remarkController,
                    minLines: 1,
                    maxLines: 1,
                    maxLength: null,
                    contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 20),
                    child: Text(
                      '对方发来的验证消息为："$msg"',
                      style: const TextStyle(color: AppColors.LabelTextColor),
                    ),
                  ),
                  IconTextView(
                    leftText: '添加标签'.tr,
                    paddingLeft: 10,
                    onPressed: () {
                      Get.snackbar('Tips', '功能在开发者，请稍等');
                    },
                    decoration: ShapeDecoration(
                      color: const Color.fromARGB(255, 247, 247, 247),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadiusDirectional.circular(5),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 14,
                    ),
                    child: Text('设置朋友圈'.tr),
                  ),
                  Card(
                    color: const Color.fromARGB(255, 247, 247, 247),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusDirectional.circular(5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: n.Column(
                      [
                        IMBoyRadioListTile(
                          value: "all",
                          title: n.Text("聊天、朋友圈、运动数据等".tr),
                          selected: false,
                          secondary:
                              logic.role.value == "all" ? secondary : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primaryElement,
                          groupValue: logic.role.value,
                          contentPadding:
                              const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          onChanged: (val) {
                            logic.setRole(val.toString());
                            logic.visibilityLook = true.obs;
                            logic.update([logic.visibilityLook]);
                            debugPrint(
                                "on >>> logic.visibilityLook1 ${logic.visibilityLook}");
                          },
                        ),
                        IMBoyRadioListTile(
                          value: "justchat",
                          title: n.Text("仅聊天".tr),
                          selected: false,
                          secondary:
                              logic.role.value == "justchat" ? secondary : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: AppColors.primaryElement,
                          groupValue: logic.role.value,
                          contentPadding:
                              const EdgeInsets.fromLTRB(10, 0, 10, 0),
                          onChanged: (val) {
                            logic.setRole(val.toString());
                            logic.visibilityLook = false.obs;
                            logic.donotlethimlook = false.obs;
                            logic.donotlookhim = false.obs;
                            logic.update();
                            debugPrint(
                                "on >>> logic.visibilityLook2 ${logic.visibilityLook}");
                            debugPrint(
                                "on >>> logic.donotlethimlook3 ${logic.donotlethimlook}");
                          },
                        ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: logic.visibilityLook.isTrue,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 50,
                      ),
                      child: n.Column(
                        [
                          Text('朋友圈和状态'.tr),
                          Card(
                            color: const Color.fromARGB(255, 247, 247, 247),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadiusDirectional.circular(5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: n.Column(
                              [
                                SwitchListTile(
                                  title: Text('不让他（她）看'.tr),
                                  value: logic.donotlethimlook.isTrue,
                                  activeColor: AppColors.primaryElement,
                                  onChanged: (val) {
                                    logic.donotlethimlook.value = val;
                                    logic.update([logic.donotlethimlook]);
                                  },
                                ),
                                SwitchListTile(
                                  title: Text('不看他（她）'.tr),
                                  value: logic.donotlookhim.isTrue,
                                  activeColor: AppColors.primaryElement,
                                  onChanged: (val) {
                                    logic.donotlookhim.value = val;
                                    logic.update([logic.donotlookhim]);
                                  },
                                ),
                              ],
                            ),
                          ),
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
      ),
    );
  }
}
