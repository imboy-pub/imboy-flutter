import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/icon_text.dart';
import 'package:imboy/component/ui/radio_list_title.dart';
import 'package:imboy/component/ui/title_text_field.dart';
import 'package:imboy/config/theme.dart';

import 'package:imboy/page/user_tag/user_tag_relation/user_tag_relation_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

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
    super.key,
    required this.from,
    required this.to,
    required this.msg,
    required this.nickname,
    required this.payload,
  });

  @override
  Widget build(BuildContext context) {
    _remarkController.text = nickname;

    Widget secondary = const Text(
      '√',
      style: TextStyle(
        fontSize: 20,
        color: Colors.green,
      ),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        title: 'accept_friend_request'.tr,
        automaticallyImplyLeading: true,
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
                "remark": _remarkController.text, // 给对端的备注
                "account": UserRepoLocal.to.current.account,
                "nickname": UserRepoLocal.to.current.nickname,
                "avatar": UserRepoLocal.to.current.avatar,
                "sign": UserRepoLocal.to.current.sign,
                "gender": UserRepoLocal.to.current.gender,
                "role": logic.role.value, // role 可能的值 all just_chat
                "donotlookhim": logic.donotlookhim.isTrue,
                "donotlethimlook": logic.donotlethimlook.isTrue,
                "tag": logic.peerTag.isEmpty ? '' : "${logic.peerTag.value},",
              };
              debugPrint("> on payload $p2");
              await logic.confirm(from, to, p2);
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                Theme.of(context).colorScheme.background,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                Theme.of(context).colorScheme.onBackground,
              ),
              minimumSize: MaterialStateProperty.all(const Size(40, 40)),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(EdgeInsets.zero),
            ),
            child: n.Padding(
                left: 10,
                right: 10,
                child: Text(
                  'button_accomplish'.tr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                )),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.background,
          child: Padding(
            padding: const EdgeInsets.only(
              left: 30,
              top: 10,
              right: 30,
            ),
            child: Obx(() => n.Column([
                  TitleTextField(
                    title: 'set_remark'.tr,
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
                      // style: const TextStyle(color: AppColors.LabelTextColor),
                    ),
                  ),
                  Obx(() => IconTextView(
                        leftText: logic.peerTag.isEmpty
                            ? 'add_tag'.tr
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
                          color: Get.isDarkMode
                              ? darkInputFillColor
                              : lightInputFillColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusDirectional.circular(5),
                          ),
                        ),
                      )),
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 14,
                    ),
                    child: Text('set_moment'.tr),
                  ),
                  Card(
                    color: Get.isDarkMode
                        ? darkInputFillColor
                        : lightInputFillColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadiusDirectional.circular(5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: n.Column([
                      IMBoyRadioListTile(
                        value: "all",
                        title: n.Text('chat_moment_sport_data_etc'.tr),
                        selected: false,
                        secondary: logic.role.value == "all" ? secondary : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Theme.of(context).colorScheme.primary,
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
                        value: "just_chat",
                        title: n.Text('just_chat'.tr),
                        selected: false,
                        secondary:
                            logic.role.value == "just_chat" ? secondary : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: Theme.of(context).colorScheme.primary,
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
                        Text('moment_status'.tr),
                        Card(
                          color: Get.isDarkMode
                              ? darkInputFillColor
                              : lightInputFillColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadiusDirectional.circular(5),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: n.Column(
                            [
                              SwitchListTile(
                                title: Text('not_let_him_see'.tr),
                                value: logic.donotlethimlook.isTrue,
                                activeColor: Colors.green,
                                onChanged: (val) {
                                  logic.donotlethimlook.value = val;
                                  logic.update([logic.donotlethimlook]);
                                },
                              ),
                              SwitchListTile(
                                title: Text('not_see_him'.tr),
                                value: logic.donotlookhim.isTrue,
                                activeColor: Colors.green,
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
