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

import 'apply_friend_logic.dart';

// ignore: must_be_immutable
class ApplyFriendPage extends StatelessWidget {
  String uid;
  String remark;
  String avatar;
  String region;
  String source;

  ApplyFriendPage(
    this.uid,
    this.remark,
    this.avatar,
    this.region, {
    required this.source,
    super.key,
  });

  final ApplyFriendLogic logic = Get.put(ApplyFriendLogic());

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _remarkController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    _msgController.text = "${'i_am'.tr} ${UserRepoLocal.to.current.nickname}";
    _remarkController.text = remark;

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
        title: 'apply_add_friend'.tr,
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
              var nav = Navigator.of(context);
              Map<String, dynamic> payload = {
                "from": {
                  "source": source,
                  "msg": _msgController.text,
                  "remark": _remarkController.text,
                  "account": UserRepoLocal.to.current.account,
                  "nickname": UserRepoLocal.to.current.nickname,
                  "avatar": UserRepoLocal.to.current.avatar,
                  "sign": UserRepoLocal.to.current.sign,
                  "gender": UserRepoLocal.to.current.gender,
                  "region": UserRepoLocal.to.current.region,

                  "role": logic.role.value, // role 可能的值 all just_chat
                  // donotlookhim 前后端约定的名称，请不要随意修改
                  "donotlookhim": logic.donotlookhim.isTrue,
                  // donotlethimlook 前后端约定的名称，请不要随意修改
                  "donotlethimlook": logic.donotlethimlook.isTrue,
                  "tag": logic.peerTag.isEmpty ? '' : "${logic.peerTag.value},",
                },
                "to": {}
              };
              await logic.apply(
                to: uid,
                peerNickname: remark,
                peerAvatar: avatar,
                payload: payload,
              );
              nav.pop();
              nav.pop();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(
                Theme.of(context).colorScheme.background,
              ),
              foregroundColor: MaterialStateProperty.all<Color>(
                Theme.of(context).colorScheme.onBackground,
              ),
              minimumSize: MaterialStateProperty.all(const Size(60, 40)),
              visualDensity: VisualDensity.compact,
              padding: MaterialStateProperty.all(EdgeInsets.zero),
            ),
            child: Text(
              'button_send'.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height + 200,
          color: Theme.of(context).colorScheme.background,
          child: n.Padding(
            left: 30,
            top: 10,
            right: 30,
            child: Obx(() => n.Column([
                  TitleTextField(
                    title: 'send_friend_request'.tr,
                    controller: _msgController,
                    minLines: 3,
                    maxLines: 4,
                    maxLength: 100,
                    contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  ),
                  TitleTextField(
                    title: 'set_remark'.tr,
                    controller: _remarkController,
                    minLines: 1,
                    maxLines: 1,
                    maxLength: 80,
                    contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  ),
                  Text('tags'.tr),
                  Obx(() => IconTextView(
                        // leftText: 'add_tag'.tr,
                        leftText: logic.peerTag.isEmpty
                            ? 'add_tag'.tr
                            : logic.peerTag.value,
                        paddingLeft: 10,
                        onPressed: () {
                          Get.to(
                            () => UserTagRelationPage(
                              peerId: uid,
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
                        activeColor: Colors.green,
                        groupValue: logic.role.value,
                        contentPadding: const EdgeInsets.fromLTRB(
                          10,
                          0,
                          10,
                          0,
                        ),
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
                        activeColor: Colors.green,
                        groupValue: logic.role.value,
                        contentPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                        onChanged: (val) {
                          logic.setRole(val.toString());
                          logic.visibilityLook = false.obs;
                          logic.donotlethimlook = false.obs;
                          logic.donotlookhim = false.obs;
                          logic.update();
                          debugPrint(
                              "> on logic.visibilityLook2 ${logic.visibilityLook}");
                          debugPrint(
                              "> on logic.donotlethimlook3 ${logic.donotlethimlook}");
                        },
                      ),
                    ]),
                  ),
                  Visibility(
                    visible: logic.visibilityLook.isTrue,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: 10,
                        bottom: 50,
                      ),
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
                          child: n.Column([
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
                          ]),
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
