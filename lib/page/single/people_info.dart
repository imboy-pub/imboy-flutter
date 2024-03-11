import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
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
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class PeopleInfoPage extends StatelessWidget {
  final String id; // 用户ID
  final String scene; // denylist or other value

  // late Rx<ContactModel> people;
  RxString nickname = "".obs;
  RxString avatar = "".obs;
  RxString account = "".obs;
  RxString region = "".obs;
  RxString sign = "".obs;
  RxString source = "".obs;
  RxString title = "".obs;
  RxInt gender = 0.obs;
  RxString remark = "".obs;
  RxString tag = "".obs;
  RxInt isFriend = 0.obs;
  RxInt isFrom = 0.obs;

  PeopleInfoPage({
    super.key,
    required this.id,
    required this.scene,
  });

  Future<void> initData() async {
    iPrint("people_info.initData 10 ${DateTime.now()}");
    ContactModel? ct = await ContactRepo().findByUid(id);
    iPrint("people_info.initData 20 ${DateTime.now()}");
    // debugPrint("> on cdv initData $id");
    // debugPrint("> on cdv initData ${ct?.toJson().toString()}");
    if (ct != null) {
      title.value = ct.title;
      nickname.value = ct.nickname;
      avatar.value = ct.avatar;
      account.value = ct.account;
      region.value = ct.region;
      sign.value = ct.sign;
      source.value = ct.source;
      gender.value = ct.gender;
      remark.value = ct.remark;
      tag.value = ct.tag;
      isFriend.value = ct.isFriend;
      isFrom.value = ct.isFrom;
      tag.value = ct.tag;
    }
    if (isFriend.value != 1) {
      if (scene == 'qrcode') {
        source.value = 'qrcode';
      } else if (scene == 'visit_card') {
        source.value = 'visit_card';
      } else if (scene == 'people_nearby') {
        source.value = 'people_nearby';
      } else if (scene == 'recently_user') {
        source.value = 'recently_user';
      } else if (scene == 'contact_page' || scene == 'denylist') {
        source.value = '';
        // } else if (scene == '') {
        // } else if (scene == '') {
        // } else if (scene == '') {
        // } else if (scene == '') {
      } else if (scene == '') {
        source.value = 'qrcode';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    initData();
    bool isSelf = UserRepoLocal.to.currentUid == id;
    bool showApplyFriendBtn = !isSelf;
    if (scene == 'denylist') {
      showApplyFriendBtn = false;
    }
    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '',
        // backgroundColor: Colors.white,
        rightDMActions: isSelf
            ? []
            : [
                SizedBox(
                  width: 60,
                  child: TextButton(
                    onPressed: () {
                      Get.to(
                        () => ContactSettingPage(
                          peerId: id,
                          peerAvatar: avatar.value,
                          peerAccount: account.value,
                          peerNickname: nickname.value,
                          peerGender: gender.value,
                          peerTitle: title.value,
                          peerSign: sign.value,
                          peerRegion: region.value,
                          peerSource: source.value,
                          peerRemark: remark.value,
                          peerTag: tag.value,
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
              remark: remark.value,
              nickname: nickname.value,
              account: account.value,
              avatar: avatar.value,
              gender: gender.value,
              region: region.value,
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
              visible: !isSelf,
              child: LabelRow(
                label: tag.value.isEmpty ? 'remarks_tags'.tr : 'tags'.tr,
                labelWidth: tag.value.isEmpty ? 96 : 40,
                // rValue: tag.value.isEmpty ? null : tag.value,
                isLine: true,
                lineWidth: 1.0,
                rightW: SizedBox(
                  width: Get.width - 140,
                  child: Text(
                    (tag.value.endsWith(',')
                        ? tag.value.substring(0, tag.value.length - 1)
                        : tag.value),
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
                      peerAvatar: avatar.value,
                      peerAccount: account.value,
                      peerNickname: nickname.value,
                      peerGender: gender.value,
                      peerTitle: title.value,
                      peerSign: sign.value,
                      peerRegion: region.value,
                      peerSource: source.value,
                      peerRemark: remark.value,
                      peerTag: tag,
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  )?.then((value) {
                    debugPrint(
                        "PeopleInfoPage_ContactSettingTagPage_back then $value");
                    if (value != null && value is String && value.isNotEmpty) {
                      remark.value = value.toString();
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
            if (isFriend.value == 1 || scene == 'denylist')
              LabelRow(
                label: 'more_info'.tr,
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
            isFriend.value == 1 || scene == 'denylist'
                ? Visibility(
                    visible: !isSelf,
                    child: ButtonRow(
                        margin: const EdgeInsets.only(bottom: 0.0),
                        text: 'message_call'.tr,
                        isBorder: true,
                        lineWidth: 1.0,
                        onPressed: () {
                          String peerTitle = remark.value;
                          if (peerTitle.isEmpty) {
                            peerTitle = nickname.value;
                          }
                          if (peerTitle.isEmpty) {
                            peerTitle = account.value;
                          }
                          Get.to(
                            () => ChatPage(
                              peerId: id,
                              peerTitle: peerTitle,
                              peerAvatar: avatar.value,
                              peerSign: sign.value,
                              type: 'C2C',
                            ),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        }),
                  )
                : const SizedBox.shrink(),
            if (isFriend.value == 1)
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
                        "nickname": nickname.value,
                        "avatar": avatar.value,
                        "sign": sign.value,
                      }),
                      {
                        'media': 'audio',
                      },
                    );
                  },
                ),
              ),
            isFriend.value == 1
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
                            "nickname": nickname.value,
                            "avatar": avatar.value,
                            "sign": sign.value,
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
                          nickname.value,
                          avatar.value,
                          region.value,
                          source: source.value,
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
                    'added_to_blacklist_tips'.tr,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
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

// ignore: must_be_immutable
class PeopleInfoMorePage extends StatelessWidget {
  final String id; // 用户ID
  PeopleInfoMorePage({
    super.key,
    required this.id,
  });

  RxString sign = "".obs;
  RxString sourcePrefix = "".obs;
  RxString source = "".obs;
  RxInt groupCount = 0.obs;

  Future<void> initData() async {
    ContactModel? model = await ContactRepo().findByUid(id);

    sign.value = model!.sign;
    source.value = model.sourceTr;
    // other_party 对方
    sourcePrefix.value = model.isFrom == 1 ? '' : 'other_party'.tr;
    debugPrint(
        "PeopleInfoMorePage initData $source, $sourcePrefix , sign $sign");
  }

  @override
  Widget build(BuildContext context) {
    initData();
    // bool isSelf = UserRepoLocal.to.currentUid == id;
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'social_profile'.tr,
        // backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column([
            LabelRow(
              label: 'mutual_groups_with_her'.tr,
              // 10个
              rValue: 'num_unit'.trArgs(['$groupCount']),
              isLine: true,
              lineWidth: 1.0,
              isRight: false,
              padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
              margin: const EdgeInsets.only(bottom: 10.0),
              // onPressed: () => Get.to(()=> const FriendCirclePage()),
            ),
            Visibility(
              visible: strNoEmpty(sign.value),
              child: LabelRow(
                label: 'signature'.tr,
                // rValue: sign,
                rightW: SizedBox(
                  width: Get.width - 100,
                  child: n.Row([
                    const SizedBox(width: 20),
                    // use Expanded only within a Column, Row or Flex
                    Expanded(
                        child: Text(
                      sign.value,
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    ))
                  ]),
                ),
                isLine: true,
                lineWidth: 1.0,
                isRight: false,
                isSpacer: false,
                // onPressed: () => Get.to(()=> const FriendCirclePage()),
              ),
            ),
            if (source.value.isNotEmpty)
              LabelRow(
                label: 'source'.tr,
                rValue: '$sourcePrefix ${source.value}',
                // rValue: getSourceTr(source.value),
                isLine: true,
                lineWidth: 1.0,
                isRight: false,
                onPressed: () {},
              ),
          ]),
        ),
      ),
    );
  }
}
