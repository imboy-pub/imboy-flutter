import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/confirm_alert.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/widget/item/chat_mamber.dart';
import 'package:imboy/component/widget/web_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat_background/chat_background_view.dart';
import 'package:imboy/page/search/search_view.dart';

import 'chat_info_logic.dart';
import 'chat_info_state.dart';

class ChatInfoPage extends StatefulWidget {
  final String id;

  ChatInfoPage(this.id);

  @override
  _ChatInfoPageState createState() => _ChatInfoPageState();
}

class _ChatInfoPageState extends State<ChatInfoPage> {
  final logic = Get.put(ChatInfoLogic());
  final ChatInfoState state = Get.find<ChatInfoLogic>().state;

  var model;

  bool isRemind = false;
  bool isTop = false;
  bool isDoNotDisturb = true;

  Widget buildSwitch(item) {
    return new LabelRow(
      label: item['label'],
      margin: item['label'] == '消息免打扰' ? EdgeInsets.only(top: 10.0) : null,
      isLine: item['label'] != '强提醒',
      isRight: false,
      rightW: new SizedBox(
        height: 25.0,
        child: new CupertinoSwitch(
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
      new ChatMamBer(model: model),
      new LabelRow(
        label: '查找聊天记录',
        margin: EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(SearchPage()),
      ),
      new Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      new LabelRow(
        label: '设置当前聊天背景',
        margin: EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(ChatBackgroundPage()),
      ),
      new LabelRow(
        label: '清空聊天记录',
        margin: EdgeInsets.only(top: 10.0),
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
      new LabelRow(
        label: '投诉',
        margin: EdgeInsets.only(top: 10.0),
        onPressed: () => Get.to(WebViewPage(CONST_HELP_URL, '投诉')),
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
    return new Scaffold(
      backgroundColor: chatBg,
      appBar: new ComMomBar(title: '聊天信息'),
      body: new SingleChildScrollView(
        child: new Column(children: body()),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ChatInfoLogic>();
    super.dispose();
  }
}
