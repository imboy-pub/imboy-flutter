import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/search/search_chat_view.dart';

import 'chat_setting_logic.dart';
import 'chat_setting_state.dart';

// ignore: must_be_immutable
class ChatSettingPage extends StatefulWidget {
  final String type;
  final String peerId;
  Map<String, dynamic>? options;

  ChatSettingPage(
    this.peerId, {
    super.key,
    required this.type,
    this.options,
  });

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
      title: item['title'],
      margin: item['label'] == 'no_disturbing'
          ? const EdgeInsets.only(top: 10.0)
          : null,
      isLine: item['id'] != 'strong_reminder',
      // '强提醒',
      isRight: false,
      trailing: SizedBox(
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
      // { // TODO 2024-08-15 15:19:33 聊天设置-消息免打扰
      //   'label': 'no_disturbing',
      //   'title': 'message_mute'.tr,
      //   'value': isDoNotDisturb
      // },
      // {'label': 'chat_on_top', 'title': 'top_chat'.tr, 'value': isTop},
      // {'label': 'strong_reminder', 'title': 'strong_reminder'.tr, 'value': isRemind},
    ];

    return [
      LabelRow(
        title: 'search_chat_record'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        isLine: true,
        onPressed: () {
          Get.to(
            () => SearchChatPage(
              type: widget.type,
              peerId: widget.options?['peerId'],
              peerTitle: widget.options?['peerTitle'],
              peerAvatar: widget.options?['peerAvatar'],
              peerSign:widget.options?['peerSign'] ?? '',
              conversationUk3: widget.options?['conversationUk3'],
            ),
            transition: Transition.rightToLeft,
            popGesture: true, // 右滑，返回上一页
          );
        },
      ),
      Column(
        children: switchItems.map(buildSwitch).toList(),
      ),
      // LabelRow(
      //   label: 'set_chat_background'.tr,
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
        title: 'clear_chat_record'.tr,
        margin: const EdgeInsets.only(top: 10.0),
        isLine: true,
        onPressed: () {
          String tips = 'confirm_delete_chat_record'.tr;
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
                n.Button('button_cancel'.tr.n)
                  ..style = n.NikuButtonStyle(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary)
                  ..onPressed = () {
                    Navigator.of(context).pop();
                  },
                n.Button('button_confirm'.tr.n)
                  ..style = n.NikuButtonStyle(
                      foregroundColor: Theme.of(context).colorScheme.onPrimary)
                  ..onPressed = () async {
                    Navigator.of(context).pop();

                    int cid = await logic.cleanMessageByPeerId(
                        widget.type, widget.peerId);
                    if (cid > 0) {
                      backDoRefresh = true;
                      // 刷新会话列表
                      await Get.find<ConversationLogic>().hideConversation(cid);
                      // 刷新会话列表
                      await Get.find<ConversationLogic>().conversationsList();
                      EasyLoading.showSuccess('tip_success'.tr);
                    } else {
                      EasyLoading.showError('tip_failed'.tr);
                    }
                  },
              ],
            barrierDismissible: true,
          );
        },
      ),
      /*
      LabelRow(
          label: 'complaint'.tr,
          margin: const EdgeInsets.only(top: 10.0),
          onPressed: () {
            Get.to(
              () => WebViewPage(CONST_HELP_URL, 'complaint'.tr),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        leading: BackButton(
          onPressed: () {
            Get.back(result: backDoRefresh);
          },
        ),
        title: 'chat_settings'.tr,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        child: n.Column(body()),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<ChatSettingLogic>();
    super.dispose();
  }
}
