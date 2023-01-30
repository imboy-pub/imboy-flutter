import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/confirm_alert.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_background/chat_background_view.dart';
import 'package:imboy/page/search/search_view.dart';

import 'chat_setting_logic.dart';
import 'chat_setting_state.dart';
import 'widget/chat_member.dart';

// ignore: must_be_immutable
class ChatSettingPage extends StatefulWidget {
  final String peerId;
  Map<String, dynamic>? options;

  ChatSettingPage(this.peerId, {Key? key, this.options}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ChatSettingPageState createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends State<ChatSettingPage> {
  final logic = Get.put(ChatSettingLogic());
  final ChatSettingState state = Get.find<ChatSettingLogic>().state;

  bool isRemind = false;
  bool isTop = false;
  bool isDoNotDisturb = true;

  Widget buildSwitch(item) {
    return LabelRow(
      label: item['label'],
      margin: item['id'] == 'no_disturbing'
          ? const EdgeInsets.only(top: 10.0)
          : null,
      isLine: item['id'] != 'strong_reminder', // '强提醒',
      isRight: false,
      rightW: SizedBox(
        height: 25.0,
        child: CupertinoSwitch(
          value: item['value'],
          onChanged: (v) {},
        ),
      ),
      onPressed: () {},
    );
  }

  List<Widget> body() {
    List switchItems = [
      {'id': 'no_disturbing', 'label': '消息免打扰'.tr, 'value': isDoNotDisturb},
      {'id': 'chat_on_top', 'label': '置顶聊天'.tr, 'value': isTop},
      {'id': 'strong_reminder', 'label': '强提醒'.tr, 'value': isRemind},
    ];

    return [
      ChatMember(options: widget.options!),
      LabelRow(
        label: '查找聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          // Get.to(const SearchPage());
        },
      ),
      Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      LabelRow(
        label: '设置当前聊天背景'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          // Get.to(const ChatBackgroundPage());
        },
      ),
      LabelRow(
        label: '清空聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          confirmAlert(
            context,
            (isOK) {
              if (isOK) {
                Get.snackbar('', '敬请期待');
              }
            },
            tips: '确定删除聊天记录吗？'.tr,
            okBtn: '清空'.tr,
          );
        },
      ),
      LabelRow(
        label: '投诉'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(() => WebViewPage(CONST_HELP_URL, '投诉'.tr)),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    getInfo();
  }

  getInfo() async {
    // final info = await getUsersProfile([widget.id]);
    // List infoList = json.decode(info);
    // setState(() {
    //   model = PersonEntity.fromJson(infoList[0]);
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(title: '聊天设置'.tr),
      body: SingleChildScrollView(
        child: Column(children: body()),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ChatSettingLogic>();
    super.dispose();
  }
}
