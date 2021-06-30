import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/chat/contact_card.dart';
import 'package:imboy/component/ui/button_row.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/page/friend_circle/friend_circle_view.dart';
import 'package:imboy/page/set_remark/set_remark_view.dart';

import 'contact_detail_logic.dart';
import 'contact_detail_state.dart';

class ContactDetailPage extends StatefulWidget {
  final String id; // 用户ID
  final String nickname;
  final String avatar;
  final String account;
  final String area;

  ContactDetailPage({
    @required this.id,
    @required this.nickname,
    @required this.avatar,
    @required this.account,
    this.area,
  });

  @override
  _ContactDetailPageState createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends State<ContactDetailPage> {
  final logic = Get.find<ContactDetailLogic>();
  final ContactDetailState state = Get.find<ContactDetailLogic>().state;

  List<Widget> body(bool itself) {
    debugPrint("_ContactDetailPageState >>>>>>> {$widget.id}");
    return [
      new ContactCard(
        id: widget.id,
        nickname: widget.nickname,
        account: widget.account,
        avatar: widget.avatar,
        area: widget.area ?? '深圳 宝安',
        isBorder: true,
      ),
      new Visibility(
        visible: !itself,
        child: new LabelRow(
          label: '设置备注和标签',
          onPressed: () => Get.to(SetRemarkPage()),
        ),
      ),
      new Space(),
      new LabelRow(
        label: '朋友圈',
        isLine: true,
        lineWidth: 0.3,
        onPressed: () => Get.to(FriendCirclePage()),
      ),
      new ButtonRow(
        margin: EdgeInsets.only(top: 10.0),
        text: '发消息',
        isBorder: true,
        onPressed: () => Get.off(
            ChatPage(id: widget.id, title: widget.nickname, type: 'C2C')),
      ),
      new Visibility(
        visible: !itself,
        child: new ButtonRow(
          text: '语音通话',
          onPressed: () => Get.snackbar('Hi', '敬请期待'),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<ContactDetailLogic>();
    super.dispose();
  }
}
