import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/contact_card.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/contact/contact_setting_view.dart';
import 'package:imboy/page/contact/friend/add_friend_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;

// ignore: must_be_immutable
class PeopleInfoPage extends StatelessWidget {
  final String id; // 用户ID
  final String sence;

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
  RxInt isFriend = 1.obs;
  RxInt isFrom = 0.obs;

  PeopleInfoPage({
    Key? key,
    required this.id,
    required this.sence,
  }) : super(key: key);

  Future<void> initData() async {
    ContactModel? ct = await ContactRepo().findByUid(id);
    debugPrint("> on cdv initData $id");
    debugPrint("> on cdv initData ${ct?.toJson().toString()}");
    title.value = ct!.title;
    nickname.value = ct.nickname;
    avatar.value = ct.avatar;
    account.value = ct.account;
    region.value = ct.region;
    sign.value = ct.sign;
    source.value = ct.source;
    gender.value = ct.gender;
    remark.value = ct.remark;
    isFriend.value = ct.isFriend;
    isFrom.value = ct.isFrom;
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
              ContactSettingPage(
                id: id,
                remark: remark.value,
              ),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: n.Padding(
            right: 10,
            child: const Icon(
              Icons.more_horiz,
              // size: 40,
            ),
          ),
        ),
      )
    ];
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '',
        backgroundColor: Colors.white,
        rightDMActions: isSelf ? [] : rWidget,
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
                  label: '备注和标签'.tr,
                  isLine: true,
                  onPressed: () => EasyLoading.showToast('敬请期待'),
                ),
              ),
              /*
              Visibility(
                visible: !isSelf,
                child: LabelRow(
                  label: '朋友权限'.tr,
                  onPressed: () => EasyLoading.showToast('敬请期待'),
                ),
              ),
              const Space(),
              LabelRow(
                label: '朋友圈'.tr,
                isLine: true,
                onPressed: () => Get.to(
                  const FriendCirclePage(),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                ),
              ),
              */
              if (isFriend.value == 1)
                LabelRow(
                  label: '更多信息'.tr,
                  isLine: false,
                  onPressed: () => Get.to(
                    PeopleInfoMorePage(
                      id: id,
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  ),
                ),
              const Space(),
              isFriend.value == 1
                  ? Visibility(
                      visible: !isSelf,
                      child: ButtonRow(
                          margin: const EdgeInsets.only(bottom: 0.0),
                          text: '发消息',
                          isBorder: true,
                          onPressed: () {
                            Get.to(
                              ChatPage(
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
                      visible: !isSelf,
                      child: ButtonRow(
                        text: '添加到通讯录'.tr,
                        onPressed: () => Get.to(
                          AddFriendPage(
                            id,
                            nickname.value,
                            avatar.value,
                            region.value,
                            source: sence,
                          ),
                          transition: Transition.rightToLeft,
                          popGesture: true, // 右滑，返回上一页
                        ),
                      ),
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
    debugPrint("PeopleInfoMorePage initData $source, $sourcePrefix , sign $sign");
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

                // onPressed: () => Get.to(() => const FriendCirclePage()),
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
                  // onPressed: () => Get.to(() => const FriendCirclePage()),
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