import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

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
            delegate: SearchBarDelegate(
              searchLabel: '搜索'.tr,
              onTapForItem: (ConversationModel conversation) {
                sendToDialog(conversation, 3);
              },
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

  void sendToDialog(ConversationModel conversation, int callbackTime) {
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
            Future.delayed(const Duration(milliseconds: 1600), () {
              Get.close(callbackTime);
            });
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
                              sendToDialog(conversation, 2);
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

class SearchBarDelegate extends SearchDelegate {
  /// This text will be shown in the [AppBar] when
  /// current query is empty.
  final String? searchLabel;

  /// 点击搜索结果项是触发的方法
  /// Clicking on a search result item is the trigger method
  final ValueChanged<ConversationModel>? onTapForItem;

  SearchBarDelegate({
    this.onTapForItem,
    this.searchLabel,
  }) : super(
          searchFieldLabel: searchLabel,
        );

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      AnimatedOpacity(
        opacity: query.isNotEmpty ? 1.0 : 0.0,
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOutCubic,
        child: IconButton(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: AnimatedIcon(
        icon: AnimatedIcons.menu_arrow,
        progress: transitionAnimation,
      ),
      onPressed: () {
        // close(context, null);
        close(context, 'error');
      },
    );
  }

  @override
  TextInputType get keyboardType => TextInputType.text;

  Future doSearch() async {
    if (query.isEmpty) {
      return [];
    }
    final data = ContactRepo().search(kwd: query);
    return data;
  }

  @override
  Widget buildResults(BuildContext context) {
    // if (int.parse(query) >= 100) {
    //   return Center(child: Text('请输入小于 100 的数字'));
    // }
    if (query.isEmpty) {
      return Center(
        // child: Text('Filter people by name, surname or age'),
        child: Text('通过好友昵称、备注搜索好友'.tr),
      );
    }

    return FutureBuilder(
      future: doSearch(),
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasData) {
          List<ContactModel> contacts = snapshot.data;
          if (contacts.isEmpty) {
            return Center(child: Text('No person found :('.tr));
          }
          return n.Padding(
            top: 16,
            child: ListView(
              children: <Widget>[
                for (int i = 0; i < contacts.length; i++)
                  n.ListTile(
                    // selected: true,
                    onTap: () {
                      if (onTapForItem != null) {
                        onTapForItem!(
                          ConversationModel(
                            id: 0,
                            peerId: contacts[i].uid!,
                            avatar: contacts[i].avatar,
                            title: contacts[i].title,
                            subtitle: '',
                            type: 'C2C',
                            msgtype: 'text',
                            unreadNum: 0,
                          ),
                        );
                      }
                    },
                    leading: Avatar(
                      imgUri: contacts[i].avatar,
                      onTap: () {},
                    ),
                    title: n.Row([
                      Expanded(
                        child: Text(
                          // 会话对象标题
                          contacts[i].title,
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
              ],
            ),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Center(
      // child: Text('Filter people by name, surname or age'),
      child: Text('通过好友昵称、备注搜索好友'.tr),
    );
    // return ListView(
    //   children: <Widget>[
    //     ListTile(title: Text('Suggest 01')),
    //     ListTile(title: Text('Suggest 02')),
    //     ListTile(title: Text('Suggest 03')),
    //     ListTile(title: Text('Suggest 04')),
    //     ListTile(title: Text('Suggest 05')),
    //   ],
    // );
  }
}
