import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/friend_item_dialog.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'contact_detail_logic.dart';
import 'contact_detail_more_view.dart';
import 'widget/contact_card.dart';

// ignore: must_be_immutable
class ContactDetailPage extends StatefulWidget {
  final String id; // 用户ID
  final String nickname;
  final String avatar;
  final String account;
  final String region;
  final String sign;
  final String source;
  int gender;

  ContactDetailPage({
    Key? key,
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.account,
    this.region = "",
    this.sign = "",
    this.source = "",
    this.gender = 0,
  }) : super(key: key);

  @override
  _ContactDetailPageState createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final logic = Get.put(ContactDetailLogic());

  List<Widget> body(bool itself) {
    return [
      ContactCard(
        id: widget.id,
        nickname: widget.nickname,
        account: widget.account,
        avatar: widget.avatar,
        gender: widget.gender,
        region: widget.region,
        isBorder: true,
        padding: const EdgeInsets.only(
          top: 24,
          right: 15.0,
          left: 15.0,
          bottom: 24.0,
        ),
      ),
      Visibility(
        visible: !itself,
        child: LabelRow(
          label: '设置备注和标签'.tr,
          isLine: true,
          onPressed: () => EasyLoading.showToast('敬请期待'),
        ),
      ),
      Visibility(
        visible: !itself,
        child: LabelRow(
          label: '朋友权限'.tr,
          onPressed: () => EasyLoading.showToast('敬请期待'),
        ),
      ),
      const Space(),
      LabelRow(
        label: '朋友圈'.tr,
        isLine: true,
        onPressed: () => EasyLoading.showToast('敬请期待'),
        // onPressed: () => Get.to(() => const FriendCirclePage()),
      ),
      LabelRow(
        label: '更多信息'.tr,
        isLine: false,
        onPressed: () => Get.to(
          () => ContactDetailMorePage(
            id: widget.id,
          ),
        ),
      ),
      ButtonRow(
        margin: const EdgeInsets.only(top: 10.0),
        text: '发消息',
        isBorder: true,
        onPressed: () => Get.to(
          () => ChatPage(
            id: 0,
            toId: widget.id,
            title: widget.nickname,
            avatar: widget.avatar,
            type: 'C2C',
          ),
        ),
      ),
      Visibility(
        visible: !itself,
        child: ButtonRow(
          text: '音视频通话',
          onPressed: () => EasyLoading.showToast('敬请期待'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    var currentUser = UserRepoLocal.to.currentUser;
    bool isSelf = currentUser.uid == widget.id;
    var rWidget = [
      SizedBox(
        width: 60,
        child: TextButton(
          onPressed: () =>
              friendItemDialog(context, userId: widget.id, suCc: (v) {
            if (v) Navigator.of(context).maybePop();
          }),
          child: const Image(
            image: AssetImage(contactAssets + 'ic_contacts_details.png'),
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

  @override
  void dispose() {
    Get.delete<ContactDetailLogic>();
    super.dispose();
  }
}
