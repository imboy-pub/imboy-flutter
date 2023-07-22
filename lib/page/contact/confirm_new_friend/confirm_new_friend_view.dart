import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/icon_text.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/component/ui/title_text_field.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'confirm_new_friend_logic.dart';

// ignore: must_be_immutable
class ConfirmNewFriendPage extends StatelessWidget {
  final ConfirmNewFriendLogic logic = Get.put(ConfirmNewFriendLogic());

  final TextEditingController _remarkController = TextEditingController();

  final String from;
  final String to;
  final String msg;
  final String nickname;
  String payload;

  ConfirmNewFriendPage({
    Key? key,
    required this.from,
    required this.to,
    required this.msg,
    required this.nickname,
    required this.payload,
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
            onPressed: () async {
              Map<String, dynamic> p2 = json.decode(payload);
              p2['to'] = {
                "remark": _remarkController.text,
                "avatar": UserRepoLocal.to.current.avatar,
                "nickname": UserRepoLocal.to.current.nickname,
                "role": logic.role.value, // role 可能的值 all justchat
                "donotlookhim": logic.donotlookhim.isTrue,
                "donotlethimlook": logic.donotlethimlook.isTrue,
                "tag": "${logic.peerTag.value},",
              };
              debugPrint("> on payload $p2");
              await logic.confirm(from, to, p2);
            },
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
            child: Text(
              '完成'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
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
            child: Obx(() => n.Column([
                  TitleTextField(
                    title: '设置备注'.tr,
                    controller: _remarkController,
                    minLines: 1,
                    maxLines: 1,
                    maxLength: 80,
                    contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 0, bottom: 20),
                    child: Text(
                      '对方发来的验证消息为："$msg"',
                      style: const TextStyle(color: AppColors.LabelTextColor),
                    ),
                  ),
                  Obx(() => IconTextView(
                        leftText: logic.peerTag.isEmpty
                            ? '添加标签'.tr
                            : logic.peerTag.value,
                        paddingLeft: 10,
                        onPressed: () {
                          Get.to(
                            () => UserTagRelationPage(
                              peerId: from,
                              peerTag: logic.peerTag.isEmpty
                                  ? ''
                                  : logic.peerTag.value,
                              scene: 'friend',
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          )?.then((value) {
                            if (value != null && value is String) {
                              logic.peerTag.value = value.toString();
                            }
                          });
                        },
                        decoration: ShapeDecoration(
                          color: const Color.fromARGB(255, 247, 247, 247),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusDirectional.circular(5),
                          ),
                        ),
                      )),
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
                    child: n.Column([
                      IMBoyRadioListTile(
                        value: "all",
                        title: n.Text("聊天、朋友圈、运动数据等".tr),
                        selected: false,
                        secondary: logic.role.value == "all" ? secondary : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: AppColors.primaryElement,
                        groupValue: logic.role.value,
                        contentPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        onChanged: (val) {
                          logic.setRole(val.toString());
                          logic.visibilityLook = true.obs;
                          logic.update([logic.visibilityLook]);
                          debugPrint(
                              "> on logic.visibilityLook1 ${logic.visibilityLook}");
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
                        contentPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        onChanged: (val) {
                          logic.setRole(val.toString());
                          logic.visibilityLook = false.obs;
                          logic.donotlethimlook = false.obs;
                          logic.donotlookhim = false.obs;
                          logic.update();
                          // debugPrint(
                          //     "> on logic.visibilityLook2 ${logic.visibilityLook}");
                          // debugPrint(
                          //     "> on logic.donotlethimlook3 ${logic.donotlethimlook}");
                        },
                      ),
                    ]),
                  ),
                  Visibility(
                    visible: logic.visibilityLook.isTrue,
                    child: n.Padding(
                      top: 10,
                      bottom: 50,
                      child: n.Column([
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
                      ])
                        ..crossAxisAlignment = CrossAxisAlignment.start,
                    ),
                  ),
                ])
                  ..crossAxisAlignment = CrossAxisAlignment.start
                  ..mainAxisSize = MainAxisSize.min),
          ),
        ),
      ),
    );
  }
}
