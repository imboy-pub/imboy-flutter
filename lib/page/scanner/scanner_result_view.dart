import 'package:flutter/material.dart';
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
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

// ignore: must_be_immutable
class ScannerResultPage extends StatelessWidget {
  final String id; // 用户ID
  final String remark;
  String nickname;
  final String avatar;
  final String region;
  final String sign;
  final bool isFriend;
  String source;
  int gender;

  ScannerResultPage({
    Key? key,
    required this.id,
    this.remark = "",
    required this.nickname,
    required this.avatar,
    required this.isFriend,
    this.region = "",
    this.sign = "",
    this.gender = 0,
    this.source = "uqrcode",
  }) : super(key: key);

  List<Widget> body(bool itself) {
    return [
      ContactCard(
        id: id,
        remark: remark,
        nickname: nickname,
        gender: gender,
        account: '',
        avatar: avatar,
        region: region,
        isBorder: true,
      ),
      Visibility(
        visible: !itself,
        child: LabelRow(
          label: '备注和标签'.tr,
          onPressed: () {},
        ),
      ),
      const Space(),
      strEmpty(sign)
          ? const SizedBox.shrink()
          : LabelRow(
              label: '个性签名'.tr,
              labelWidth: 68.0,
              isSpacer: false,
              rightW: Container(
                width: Get.width - 100,
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  sign,
                  style: TextStyle(
                    color: AppColors.MainTextColor.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // onPressed: () {},
              isLine: true,
              isRight: false,
            ),
      LabelRow(
        label: '来源'.tr,
        rValue: '来自扫一扫'.tr,
        // rightW: Expanded(
        //     child: Padding(
        //   padding: EdgeInsets.only(left: 24),
        //   child: Text(
        //     '来自扫一扫'.tr,
        //     style: TextStyle(
        //         color: AppColors.MainTextColor.withOpacity(0.8),
        //         fontWeight: FontWeight.w500),
        //   ),
        // )),
        isLine: false,
        isRight: false,
        onPressed: () {},
      ),
      const Space(),
      isFriend
          ? Visibility(
              visible: !itself,
              child: ButtonRow(
                  margin: const EdgeInsets.only(bottom: 0.0),
                  text: '发消息',
                  isBorder: true,
                  onPressed: () {
                    Get.to(
                      ChatPage(
                        peerId: id,
                        peerTitle: nickname,
                        peerAvatar: avatar,
                        peerSign: sign,
                        type: 'C2C',
                      ),
                      transition: Transition.rightToLeft,
                      popGesture: true, // 右滑，返回上一页
                    );
                  }),
            )
          : const SizedBox.shrink(),
      if (isFriend)
        Visibility(
          visible: !itself,
          child: ButtonRow(
            text: '语音通话'.tr,
            isBorder: true,
            onPressed: () {
              openCallScreen(
                UserModel.fromJson({
                  "uid": id,
                  "nickname": nickname,
                  "avatar": avatar,
                  "sign": sign,
                }),
                {
                  'media': 'audio',
                },
              );
            },
          ),
        ),
      isFriend
          ? Visibility(
              visible: !itself,
              child: ButtonRow(
                text: '视频通话'.tr,
                onPressed: () {
                  openCallScreen(
                    UserModel.fromJson({
                      "uid": id,
                      "nickname": nickname,
                      "avatar": avatar,
                      "sign": sign,
                    }),
                    {},
                  );
                },
              ),
            )
          : Visibility(
              visible: !itself,
              child: ButtonRow(
                text: '添加到通讯录'.tr,
                onPressed: () => Get.to(
                  AddFriendPage(
                    id,
                    nickname,
                    avatar,
                    region,
                  ),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                ),
              ),
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // final global = Provider.of<GlobalModel>(context, listen: false);
    var currentUser = UserRepoLocal.to.current;
    bool isSelf = currentUser.uid == id;
    var rWidget = [
      SizedBox(
        width: 60,
        child: TextButton(
          // padding: EdgeInsets.all(0),
          onPressed: () {
            Get.to(
              ContactSettingPage(
                id: id,
                remark: nickname, // TODO user remark ? user nickname?
              ),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          },
          child: const Image(
            image: AssetImage('assets/images/right_more.png'),
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
        child: Column(children: body(isSelf)),
      ),
    );
  }
}
