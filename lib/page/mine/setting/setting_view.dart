import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/view/list_tile_view.dart';
import 'package:imboy/config/const.dart';

import 'setting_logic.dart';
import 'setting_state.dart';

class SettingPage extends StatefulWidget {
  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final logic = Get.put(SettingLogic());
  final SettingState state = Get.find<SettingLogic>().state;

  Widget buildContent(item) {
    return new ListTileView(
      title: item['label'],
      titleStyle: TextStyle(fontSize: 15.0),
      padding: new EdgeInsets.fromLTRB(24, 16, 8, 8),
      // padding: EdgeInsets.symmetric(vertical: 16.0),
      border: item['border'],
      margin: EdgeInsets.symmetric(vertical: item['vertical']),
      onPressed: () => logic.action(item['action']),
      width: 25.0,
      fit: BoxFit.cover,
      horizontal: 15.0,
    );
  }

  Widget body(BuildContext context) {
    List data = [
      {'label': '账号与安全', 'vertical': 0.0, 'border': null},
      {
        'label': '其少年模式',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '新消息通知',
        'vertical': 0.0,
        'border': null,
      },
      {'label': '隐私', 'vertical': 0.0, 'border': null},
      {
        'label': '通用',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '帮助与反馈',
        'vertical': 0.0,
        'border': null,
      },
      {
        'label': '关于',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {'label': '切换账号', 'vertical': 10.0, 'border': null},
      {
        'label': '退出登录',
        'vertical': 0.0,
        'border': null,
        'action': 'logout',
      },
    ];

    return new Column(
      children: <Widget>[
        new Column(
          children: data.map(buildContent).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new ComMomBar(
        title: '设置',
      ),
      // color: appBarColor,
      body: new SingleChildScrollView(child: body(context)),
    );
  }

  @override
  void dispose() {
    Get.delete<SettingLogic>();
    super.dispose();
  }
}
