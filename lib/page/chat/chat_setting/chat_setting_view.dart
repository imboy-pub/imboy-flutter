import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/search/search_view.dart';
import 'package:niku/namespace.dart' as n;

import 'chat_setting_logic.dart';
import 'chat_setting_state.dart';

// ignore: must_be_immutable
class ChatSettingPage extends StatefulWidget {
  final String peerId;
  Map<String, dynamic>? options;

  ChatSettingPage(this.peerId, {super.key, this.options});

  @override
  // ignore: library_private_types_in_public_api
  _ChatSettingPageState createState() => _ChatSettingPageState();
}

class _ChatSettingPageState extends State<ChatSettingPage> {
  final logic = Get.put(ChatSettingLogic());
  final ChatSettingState state = Get.find<ChatSettingLogic>().state;

  bool backDoRefresh = false;
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
      // {'label': 'chat_on_top', 'title': '置顶聊天'.tr, 'value': isTop},
      // {'label': 'strong_reminder', 'title': '强提醒'.tr, 'value': isRemind},
    ];

    return [
      // ChatMember(options: widget.options!),
      LabelRow(
        label: '查找聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          Get.to(
            () => const SearchPage(),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      // LabelRow(
      //   label: '设置当前聊天背景'.tr,
      //   margin: const EdgeInsets.only(top: 10.0),
      //   onPressed: () {
      //     Get.to(()=>
      //       const ChatBackgroundPage(),
      //       transition: Transition.rightToLeft,
      //       popGesture: true, // 右滑，返回上一页
      //     );
      //   },
      // ),
      LabelRow(
        label: '清空聊天记录'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        onPressed: () {
          String tips = '确定删除聊天记录吗？'.tr;
          n.showDialog(
            context: Get.context!,
            builder: (context) => n.Alert()
              // ..title = Text("Session Expired")
              ..content = SizedBox(
                height: 40,
                child: Center(
                    child: Text(
                  tips,
                  style: const TextStyle(color: Colors.red),
                )),
              )
              ..actions = [
                n.Button('取消'.tr.n)
                  ..style =
                      n.NikuButtonStyle(foregroundColor: AppColors.ItemOnColor)
                  ..onPressed = () {
                    Navigator.of(context).pop();
                  },
                n.Button('确定'.tr.n)
                  ..style =
                      n.NikuButtonStyle(foregroundColor: AppColors.ItemOnColor)
                  ..onPressed = () async {
                    Navigator.of(context).pop();

                    bool res = await logic.cleanMessageByPeerId(widget.peerId);
                    if (res) {
                      backDoRefresh = true;
                      // 刷新会话列表
                      await Get.find<ConversationLogic>()
                          .hideConversation(widget.peerId);
                      // 刷新会话列表
                      await Get.find<ConversationLogic>().conversationsList();
                      EasyLoading.showSuccess('操作成功'.tr);
                    } else {
                      EasyLoading.showError('操作失败'.tr);
                    }
                  },
              ],
            barrierDismissible: true,
          );
        },
      ),
      /*
      LabelRow(
          label: '投诉'.tr,
          margin: const EdgeInsets.only(top: 10.0),
          onPressed: () {
            Get.to(
              () => WebViewPage(CONST_HELP_URL, '投诉'.tr),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          }),
      */
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
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(
        leading: BackButton(
          onPressed: () {
            Get.back(result: backDoRefresh);
          },
        ),
        title: '聊天设置'.tr,
      ),
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
