import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/confirm_alert.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat_background/chat_background_view.dart';
import 'package:imboy/page/search/search_view.dart';

import 'chat_info_logic.dart';
import 'chat_info_state.dart';
import 'widget/chat_mamber.dart';

class ChatInfoPage extends StatefulWidget {
  final String id;

  const ChatInfoPage(this.id, {Key? key}) : super(key: key);

  @override
  _ChatInfoPageState createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  final logic = Get.put(ChatInfoLogic());
  final ChatInfoState state = Get.find<ChatInfoLogic>().state;

  // ignore: prefer_typing_uninitialized_variables
  var model;

  bool isRemind = false;
  bool isTop = false;
  bool isDoNotDisturb = true;

  Widget buildSwitch(item) {
    return LabelRow(
      label: item['label'],
      margin: item['label'] == '消息免打扰' ? const EdgeInsets.only(top: 10.0) : null,
      isLine: item['label'] != '强提醒',
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
      {"label": '消息免打扰', 'value': isDoNotDisturb},
      {"label": '置顶聊天', 'value': isTop},
      {"label": '强提醒', 'value': isRemind},
    ];

    return [
      ChatMamBer(model: model),
      LabelRow(
        label: '查找聊天记录',
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(() => const SearchPage()),
      ),
      Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      LabelRow(
        label: '设置当前聊天背景',
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(() => const ChatBackgroundPage()),
      ),
      LabelRow(
        label: '清空聊天记录',
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          confirmAlert(
            context,
            (isOK) {
              if (isOK) {
                Get.snackbar('', '敬请期待');
              }
            },
            tips: '确定删除群的聊天记录吗？',
            okBtn: '清空',
          );
        },
      ),
      LabelRow(
        label: '投诉',
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(() => WebViewPage(CONST_HELP_URL, '投诉')),
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
      appBar: const PageAppBar(title: '聊天信息'),
      body: SingleChildScrollView(
        child: Column(children: body()),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ChatInfoLogic>();
    super.dispose();
  }
}
