import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:niku/namespace.dart' as n;
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:search_page/search_page.dart';

import 'send_to_logic.dart';

/// 发送给 页面
class SendToPage extends StatelessWidget {
  final types.Message msg;

  SendToPage({super.key, required this.msg});

  final logic = Get.put(SendToLogic());

  final state = Get.find<SendToLogic>().state;

  void initData() async {
    await logic.conversationsList();
  }

  @override
  Widget build(BuildContext context) {
    initData();
    var topRightWidget = [
      InkWell(
        child: n.Padding(
          top: 14,
          right: 10,
          child: Text('多选'.tr),
        ),
        onTap: () {},
      )
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PageAppBar(
        title: '转发给'.tr,
        rightDMActions: topRightWidget,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: searchBoxBuild(context),
      body: n.Column([
        // line
        Container(
          width: Get.width,
          height: 8,
          color: AppColors.ChatBg,
          // color: Colors.red,
          margin: const EdgeInsets.only(top: 53.0),
        ),
        /*
        SizedBox(
          width: Get.width,
          child: n.Column(
            [
              ListTile(
                title: Text('最近转发'.tr),
              ),
              n.Row([])
            ],
          ),
        ),
        // line
        Container(
          // margin: const EdgeInsets.only(top: 53.0),
          width: Get.width,
          height: 8,
          color: AppColors.ChatBg,
        ),
        */
        Expanded(
          flex: 1,
          child: SizedBox(
            width: Get.width,
            // height: 460,
            // color: AppColors.ChatBg,
            // color: Colors.red,
            child: n.Column(
              [
                ListTile(
                  title: Text(
                    '最近聊天'.tr,
                  ),
                ),
                Expanded(
                  child: conversationBuild(),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget searchBoxBuild(BuildContext context) {
    // TODO leeyi 2023-01-29 16:56:14
    return Container(
      margin: const EdgeInsets.only(top: 58.0, left: 0, right: 0),
      padding: const EdgeInsets.only(left: 10),
      color: Colors.white,
      // color: Colors.red,
      width: Get.width,
      height: 48.0,
      child: InkWell(
        onTap: () {
          showSearch(
            context: context,
            delegate: SearchPage<Person>(
              items: [],
              searchLabel: 'Search people',
              suggestion: Center(
                child: Text('Filter people by name, surname or age'),
              ),
              failure: Center(
                child: Text('No person found :('),
              ),
              filter: (person) => [
                person.name,
                // person.surname ?? '',
                // person.age.toString(),
              ],
              builder: (person) => ListTile(
                title: Text(person.name ?? ''),
                // subtitle: Text(person.surname),
                // trailing: Text('${person.age} yo'),
              ),
            ),
          );
        },
        child: n.Row([
          FloatingActionButton(
            // mini: true,
            backgroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 0,
            tooltip: '搜索'.tr,
            onPressed: () {},
            child: const Icon(
              Icons.search,
              color: AppColors.thirdElementText,
              size: 20,
            ),
          ),
          n.Padding(
            left: 0,
            child: Text('搜索'.tr),
          ),
        ]),
      ),
    );
  }

  void sendToDialog(ConversationModel conversation) {
    Get.defaultDialog(
      title: '发送给'.tr,
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          Get.back();
        },
        child: Text(
          '取消'.tr,
          textAlign: TextAlign.center,
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          bool res = await logic.sendMsg(conversation, msg);
          if (res) {
            EasyLoading.showSuccess('发送成功'.tr);
            Get.back();
          } else {
            EasyLoading.showError('发送失败'.tr);
          }
        },
        child: Text(
          '发送'.tr,
          textAlign: TextAlign.center,
        ),
      ),
      content: SizedBox(
        height: 200,
        child: n.Column([
          n.Row([
            Avatar(
              imgUri: conversation.avatar,
              onTap: () {},
            ),
            Expanded(
              child: n.Padding(
                left: 10,
                child: Text(
                  // 会话对象标题
                  conversation.title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ]),
          const Divider(),
          Expanded(
            child: Center(child: messageMsgWidget(msg)),
          ),
        ]),
      ),
    );
  }

  Widget conversationBuild() {
    return SingleChildScrollView(
      child: Obx(() {
        return state.conversations.isEmpty
            ? NoDataView(text: '无会话消息'.tr)
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.conversations.length,
                itemBuilder: (BuildContext context, int index) {
                  ConversationModel conversation = state.conversations[index];
                  return InkWell(
                    onTap: () {},
                    onTapDown: (TapDownDetails details) {},
                    onLongPress: () {},
                    child: state.multipleChoice.isTrue
                        ? const SizedBox.shrink()
                        : n.ListTile(
                            // selected: true,
                            onTap: () {
                              sendToDialog(conversation);
                            },
                            leading: Avatar(
                              imgUri: conversation.avatar,
                              onTap: () {},
                            ),
                            title: n.Row([
                              Expanded(
                                child: Text(
                                  // 会话对象标题
                                  conversation.title,
                                  style: const TextStyle(
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            ]),
                          ),
                  );
                },
              );
      }),
    );
  }
}
