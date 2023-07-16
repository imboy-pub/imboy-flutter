import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact/contact_setting_tag_view.dart';
import 'package:imboy/page/contact/contact_setting_view.dart';
import 'package:imboy/page/friend/apply_friend_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// ignore: must_be_immutable
class PeopleInfoPage extends StatelessWidget {
  final String id; // 用户ID
  final String scene;

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
  RxInt isFriend = 1.obs;
  RxInt isFrom = 0.obs;

  PeopleInfoPage({
    Key? key,
    required this.id,
    required this.scene,
  }) : super(key: key);

  Future<void> initData() async {
    ContactModel? ct = await ContactRepo().findByUid(id);
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
  }

  @override
  Widget build(BuildContext context) {
    initData();
    bool isSelf = UserRepoLocal.to.currentUid == id;
    var rWidget = [
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
            );
          },
          child: n.Padding(
            left: 10,
            right: 10,
            child: const Icon(
              Icons.more_horiz,
              // size: 40,
            ),
          ),
        ),
      )
    ];
    bool showApplyFriendBtn = !isSelf;
    if (scene == 'denylist') {
      showApplyFriendBtn = false;
    }
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '',
        backgroundColor: Colors.white,
        rightDMActions: isSelf ? [] : rWidget,
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column(
            [
              ContactCard(
                id: id,
                remark: remark.value,
                nickname: nickname.value,
                account: account.value,
                avatar: avatar.value,
                gender: gender.value,
                region: region.value,
                isBorder: true,
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
                  label: tag.value.isEmpty ? '备注和标签'.tr : '标签'.tr,
                  labelWidth: tag.value.isEmpty ? 96 : 40,
                  // rightW: tag.value.isEmpty ? null : Expanded(child: Text(tag.value)),
                  // rValue: tag.value.isEmpty ? null : tag.value,
                  isLine: true,
                  rightW: SizedBox(
                    width: Get.width - 140,
                    child: Text(
                      (tag.value.endsWith(',')
                          ? tag.value.substring(0, tag.value.length - 1)
                          : tag.value),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        fontSize: 17.0,
                        color: AppColors.MainTextColor,
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
                      if (value != null &&
                          value is String &&
                          value.isNotEmpty) {
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
                  label: '朋友权限'.tr,
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
                label: '朋友圈'.tr,
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
                  label: '更多信息'.tr,
                  isLine: false,
                  onPressed: () => Get.to(
                    () => PeopleInfoMorePage(
                      id: id,
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  ),
                ),
              const Space(),
              isFriend.value == 1 || scene == 'denylist'
                  ? Visibility(
                      visible: !isSelf,
                      child: ButtonRow(
                          margin: const EdgeInsets.only(bottom: 0.0),
                          text: '发消息',
                          isBorder: true,
                          onPressed: () {
                            Get.to(
                              () => ChatPage(
                                peerId: id,
                                peerTitle: nickname.value,
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
                    text: '语音通话'.tr,
                    isBorder: true,
                    onPressed: () {
                      openCallScreen(
                        UserModel.fromJson({
                          "uid": id,
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
                        text: '视频通话'.tr,
                        onPressed: () {
                          openCallScreen(
                            UserModel.fromJson({
                              "uid": id,
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
                        text: '添加到通讯录'.tr,
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
                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                    const Space(width: 4),
                    Text('已添加至黑名单，你将不再收到对方的消息'.tr),
                  ])
                    // 内容居中
                    ..mainAxisAlignment = MainAxisAlignment.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: must_be_immutable
class PeopleInfoMorePage extends StatelessWidget {
  final String id; // 用户ID
  PeopleInfoMorePage({
    Key? key,
    required this.id,
  }) : super(key: key);

  RxString sign = "".obs;
  RxString sourcePrefix = "".obs;
  RxString source = "".obs;
  RxInt groupCount = 0.obs;

  Future<void> initData() async {
    ContactModel? model = await ContactRepo().findByUid(id);

    sign.value = model!.sign;
    source.value = model.sourceTr;
    sourcePrefix.value = model.isFrom == 1 ? "" : "对方".tr;
    debugPrint(
        "PeopleInfoMorePage initData $source, $sourcePrefix , sign $sign");
  }

  @override
  Widget build(BuildContext context) {
    initData();
    // bool isSelf = UserRepoLocal.to.currentUid == id;
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '社交资料'.tr,
        // backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Obx(
          () => n.Column(
            [
              LabelRow(
                label: '我和他的共同群聊'.tr,
                rValue: '$groupCount个'.tr,
                isLine: false,
                isRight: false,
                padding: const EdgeInsets.only(top: 15.0, bottom: 15.0),
                margin: const EdgeInsets.only(bottom: 10.0),

                // onPressed: () => Get.to(()=> const FriendCirclePage()),
              ),
              Visibility(
                visible: strNoEmpty(sign.value),
                child: LabelRow(
                  label: '个性签名'.tr,
                  // rValue: sign,
                  rightW: Expanded(
                      child: Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Text(
                      sign.value,
                      style: TextStyle(
                          color: AppColors.MainTextColor.withOpacity(0.7),
                          fontWeight: FontWeight.w400),
                    ),
                  )),
                  isLine: true,
                  isRight: false,
                  isSpacer: false,
                  // onPressed: () => Get.to(()=> const FriendCirclePage()),
                ),
              ),
              if (source.isNotEmpty)
                LabelRow(
                  label: '来源'.tr,
                  rValue: '$sourcePrefix $source',
                  // rValue: getSourceTr(source.value),
                  isLine: false,
                  isRight: false,
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
  }
}
