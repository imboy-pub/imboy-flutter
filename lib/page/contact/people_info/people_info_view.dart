import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:imboy/component/webrtc/func.dart';

import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_view.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_view.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_view.dart';
import 'package:imboy/page/contact/people_info_more/people_info_more_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'people_info_logic.dart';

// ignore: must_be_immutable
class PeopleInfoPage extends StatelessWidget {
  final String id; // 用户ID
  final String scene; // denylist or other value

  PeopleInfoPage({
    super.key,
    required this.id,
    required this.scene,
  });

  final logic = Get.put(PeopleInfoLogic());
  final state = Get.find<PeopleInfoLogic>().state;

  Future<void> initData() async {
    logic.initData(id, scene);
  }

  @override
  Widget build(BuildContext context) {
    initData();
    bool isSelf = UserRepoLocal.to.currentUid == id;
    bool showApplyFriendBtn = !isSelf;
    if (scene == 'denylist' || id == 'bot_qian_fan') {
      showApplyFriendBtn = false;
    }
    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '',
        // backgroundColor: Colors.white,
        rightDMActions: isSelf || id == 'bot_qian_fan'
            ? []
            : [
                SizedBox(
                  width: 60,
                  child: TextButton(
                    onPressed: () {
                      Get.to(
                        () => ContactSettingPage(
                          peerId: id,
                          peerAvatar: state.avatar.value,
                          peerAccount: state.account.value,
                          peerNickname: state.nickname.value,
                          peerGender: state.gender.value,
                          peerTitle: state.title.value,
                          peerSign: state.sign.value,
                          peerRegion: state.region.value,
                          peerSource: state.source.value,
                          peerRemark: state.remark.value,
                          peerTag: state.tag.value,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      )?.then((value) {
                        initData();
                        // iPrint("ContactSettingPage_back $value;");
                      });
                    },
                    child: n.Padding(
                      left: 10,
                      right: 10,
                      child: Icon(
                        Icons.more_horiz,
                        color: Theme.of(context).colorScheme.onPrimary,
                        // size: 40,
                      ),
                    ),
                  ),
                )
              ],
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column([
            ContactCard(
              id: id,
              remark: state.remark.value,
              nickname: state.nickname.value,
              account: state.account.value,
              avatar: state.avatar.value,
              gender: state.gender.value,
              region: state.region.value,
              isBorder: true,
              lineWidth: 1.0,
              padding: const EdgeInsets.only(
                top: 8,
                right: 15.0,
                left: 15.0,
                bottom: 16.0,
              ),
            ),
            Visibility(
              visible: !isSelf && id != 'bot_qian_fan',
              child: LabelRow(
                title: state.tag.value.isEmpty ? 'remarks_tags'.tr : 'tags'.tr,
                titleWidth: state.tag.value.isEmpty ? 96 : 40,
                // rValue: tag.value.isEmpty ? null : tag.value,
                isLine: true,
                lineWidth: 1.0,
                trailing: SizedBox(
                  width: Get.width - 140,
                  child: Text(
                    (state.tag.value.endsWith(',')
                        ? state.tag.value
                            .substring(0, state.tag.value.length - 1)
                        : state.tag.value),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 17.0,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
                onPressed: () {
                  Get.to(
                    () => ContactSettingTagPage(
                      peerId: id,
                      peerAvatar: state.avatar.value,
                      peerAccount: state.account.value,
                      peerNickname: state.nickname.value,
                      peerGender: state.gender.value,
                      peerTitle: state.title.value,
                      peerSign: state.sign.value,
                      peerRegion: state.region.value,
                      peerSource: state.source.value,
                      peerRemark: state.remark.value,
                      peerTag: state.tag,
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  )?.then((value) {
                    debugPrint(
                        "PeopleInfoPage_ContactSettingTagPage_back then $value");
                    if (value != null && value is String && value.isNotEmpty) {
                      state.remark.value = value.toString();
                    }
                  });
                },
              ),
            ),
            /*
          Visibility(
            visible: !isSelf,
            child: LabelRow(
              label: 'friend_permissions'.tr,
              onPressed: () {
                Get.to(
                  () => FriendsPermissionsPage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
          ),
          const Space(),
          LabelRow(
            label: 'moment'.tr,
            isLine: true,
            onPressed: () => Get.to(()=>
              const FriendCirclePage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            ),
          ),
          */
            if (state.isFriend.value == 1 || scene == 'denylist')
              LabelRow(
                title: 'more_info'.tr,
                isLine: false,
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    // “右滑返回上一页”功能
                    builder: (_) => PeopleInfoMorePage(
                      id: id,
                    ),
                  ),
                ),
              ),
            HorizontalLine(
              height: 10,
              color: Theme.of(context).colorScheme.primary,
            ),
            state.isFriend.value == 1 || scene == 'denylist'
                ? Visibility(
                    visible: !isSelf,
                    child: ButtonRow(
                        margin: const EdgeInsets.only(bottom: 0.0),
                        text: 'message_call'.tr,
                        isBorder: true,
                        lineWidth: 1.0,
                        onPressed: () {
                          String peerTitle = state.remark.value;
                          if (peerTitle.isEmpty) {
                            peerTitle = state.nickname.value;
                          }
                          if (peerTitle.isEmpty) {
                            peerTitle = state.account.value;
                          }
                          Get.to(
                            () => ChatPage(
                              peerId: id,
                              peerTitle: peerTitle,
                              peerAvatar: state.avatar.value,
                              peerSign: state.sign.value,
                              type: 'C2C',
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        }),
                  )
                : const SizedBox.shrink(),
            if (state.isFriend.value == 1)
              Visibility(
                visible: !isSelf,
                child: ButtonRow(
                  text: 'voice_call'.tr,
                  isBorder: true,
                  lineWidth: 1.0,
                  onPressed: () {
                    openCallScreen(
                      ContactModel.fromMap({
                        "id": id,
                        "nickname": state.nickname.value,
                        "avatar": state.avatar.value,
                        "sign": state.sign.value,
                      }),
                      {
                        'media': 'audio',
                      },
                    );
                  },
                ),
              ),
            state.isFriend.value == 1
                ? Visibility(
                    visible: !isSelf,
                    child: ButtonRow(
                      text: 'video_call'.tr,
                      isBorder: true,
                      lineWidth: 1.0,
                      onPressed: () {
                        openCallScreen(
                          ContactModel.fromMap({
                            "id": id,
                            "nickname": state.nickname.value,
                            "avatar": state.avatar.value,
                            "sign": state.sign.value,
                          }),
                          {},
                        );
                      },
                    ),
                  )
                : Visibility(
                    visible: showApplyFriendBtn,
                    child: ButtonRow(
                      text: 'add_to_contacts'.tr,
                      onPressed: () => Get.to(
                        () => ApplyFriendPage(
                          id,
                          state.nickname.value,
                          state.avatar.value,
                          state.region.value,
                          source: state.source.value,
                        ),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      ),
                    ),
                  ),
            if (scene == 'denylist')
              n.Padding(
                top: 20,
                child: n.Row([
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const Space(width: 4),
                  Expanded(
                      child: Text(
                    'added_to_denylist_tips'.tr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  )),
                ])
                  // 内容居中
                  ..mainAxisAlignment = MainAxisAlignment.center,
              ),
          ]),
        ),
      ),
    );
  }
}
