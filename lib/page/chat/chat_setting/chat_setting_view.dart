import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_background/chat_background_view.dart';
import 'package:imboy/page/search/search_view.dart';

import 'chat_setting_logic.dart';
import 'chat_setting_state.dart';

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
      label: item['title'],
      margin: item['label'] == 'no_disturbing'
          ? const EdgeInsets.only(top: 10.0)
          : null,
      isLine: item['id'] != 'strong_reminder',
      // '强提醒',
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
      {'label': 'no_disturbing', 'title': '消息免打扰'.tr, 'value': isDoNotDisturb},
      {'label': 'chat_on_top', 'title': '置顶聊天'.tr, 'value': isTop},
      {'label': 'strong_reminder', 'title': '强提醒'.tr, 'value': isRemind},
    ];

    return [
      // ChatMember(options: widget.options!),
      LabelRow(
        label: '查找聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          Get.to(
            const SearchPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      LabelRow(
        label: '设置当前聊天背景'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          Get.to(
            const ChatBackgroundPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      LabelRow(
        label: '清空聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          String tips = '确定删除聊天记录吗？'.tr;
          Get.defaultDialog(
            title: 'Alert'.tr,
            content: Text(tips),
            textCancel: "  ${'取消'.tr}  ",
            textConfirm: "  ${'清空'.tr}  ",
            confirmTextColor: AppColors.primaryElementText,
            onConfirm: () {
              Get.back();
              EasyLoading.showSuccess('操作成功'.tr);
            },
          );
        },
      ),
      LabelRow(
          label: '投诉'.tr,
          margin: const EdgeInsets.only(top: 10.0),
          onPressed: () {
            Get.to(
              WebViewPage(CONST_HELP_URL, '投诉'.tr),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          }),
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
