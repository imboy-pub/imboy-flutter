import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button_row.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/friend_item_dialog.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/friend_circle/friend_circle_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'contact_detail_logic.dart';
import 'contact_detail_state.dart';
import 'widget/contact_card.dart';

class ContactDetailPage extends StatefulWidget {
  final String id; // 用户ID
  final String nickname;
  final String avatar;
  final String account;
  final String region;
  final String sgin;
  int gender;

  ContactDetailPage({
    required this.id,
    required this.nickname,
    required this.avatar,
    required this.account,
    this.region = "",
    this.sgin = "",
    this.gender = 0,
  });

  @override
  _ContactDetailPageState createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final logic = Get.put(ContactDetailLogic());
  final ContactDetailState state = Get.find<ContactDetailLogic>().state;

  List<Widget> body(bool itself) {
    debugPrint("_ContactDetailPageState >>>>>>> ${widget.region}");
    return [
      ContactCard(
        id: widget.id,
        nickname: widget.nickname,
        account: widget.account,
        avatar: widget.avatar,
        gender: widget.gender,
        region: widget.region,
        isBorder: true,
      ),
      Visibility(
        visible: !itself,
        child: LabelRow(
          label: '设置备注和标签'.tr,
          onPressed: () {},
        ),
      ),
      Space(),
      LabelRow(
        label: '朋友圈'.tr,
        isLine: false,
        onPressed: () => Get.to(FriendCirclePage()),
      ),
      ButtonRow(
        margin: EdgeInsets.only(top: 10.0),
        text: '发消息',
        isBorder: true,
        onPressed: () => Get.to(
          ChatPage(
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
          onPressed: () => Get.snackbar('', '敬请期待'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // final global = Provider.of<GlobalModel>(context, listen: false);
    var currentUser = UserRepoLocal.to.currentUser;
    bool isSelf = currentUser.uid == widget.id;
    var rWidget = [
      SizedBox(
        width: 60,
        child: FlatButton(
          padding: EdgeInsets.all(0),
          onPressed: () =>
              friendItemDialog(context, userId: widget.id, suCc: (v) {
            if (v) Navigator.of(context).maybePop();
          }),
          child: Image(
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
