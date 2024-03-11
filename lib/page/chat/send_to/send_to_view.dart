import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/list.dart';
import 'package:imboy/component/message/message.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'send_to_logic.dart';

/// 发送给 页面
class SendToPage extends StatelessWidget {
  final types.Message msg;
  final Function()? callback;

  SendToPage({super.key, required this.msg, this.callback});

  final logic = Get.put(SendToLogic());

  final state = Get.find<SendToLogic>().state;

  final int _itemHeight = 60;

  void initData() async {
    await logic.conversationsList();
  }

  @override
  Widget build(BuildContext context) {
    initData();
    var leading = Obx(() {
      Widget btn;
      if (state.multipleChoice.isTrue) {
        btn = InkWell(
          onTap: () {
            state.multipleChoice.value = !state.multipleChoice.value;
            state.selects.value = [];
            for (var element in state.conversations) {
              element.selected.value = false;
            }
          },
          child: n.Padding(
            top: 14,
            left: 16,
            child: Text('button_cancel'.tr),
          ),
        );
      } else {
        btn = InkWell(
          onTap: () {
            Get.back();
          },
          child: n.Padding(
            top: 14,
            left: 16,
            child: Text('button_close'.tr),
          ),
        );
      }
      return btn;
    });
    var topRightWidget = [
      InkWell(
        onTap: () {
          if (state.multipleChoice.isTrue) {
            if (state.selects.isEmpty) {
              EasyLoading.showInfo('please_select'.tr);
              return;
            }
            separatelySendToDialog(state.selects, 2);
          } else {
            state.multipleChoice.value = !state.multipleChoice.value;
          }
        },
        child: Obx(
          () {
            String suffix = '';
            if (state.selects.isNotEmpty) {
              suffix = '(${state.selects.length})';
            }
            return n.Padding(
              top: 14,
              left: 10,
              right: 10,
              bottom: 14,
              child: state.multipleChoice.isTrue
                  ? Text("${'button_accomplish'.tr}$suffix")
                  : Text('multi_select'.tr),
            );
          },
        ),
      )
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        leading: leading,
        title: 'forward_to'.tr,
        rightDMActions: topRightWidget,
        automaticallyImplyLeading: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
      floatingActionButton: searchBoxBuild(context),
      body: n.Column([
        Container(
          width: Get.width,
          height: 8,
          color: Theme.of(context).colorScheme.background,
          // color: Colors.red,
          margin: const EdgeInsets.only(top: 53.0),
        ),
        /*
        SizedBox(
          width: Get.width,
          child: n.Column(
            [
              ListTile(
                title: Text('recent_forwards'.tr),
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
            child: n.Column([
              ListTile(
                title: Text(
                  'recent_chats'.tr,
                ),
              ),
              Expanded(
                child: n.Padding(
                  left: 16,
                  child: Obx(
                    () => n.ListView(
                      itemCount: state.conversations.length,
                      children: state.conversations
                          .map((conversation) => _buildListItem(
                                context,
                                conversation,
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget searchBoxBuild(BuildContext ctx) {
    // TODO leeyi 2023-01-29 16:56:14
    return Container(
      margin: const EdgeInsets.only(top: 58.0, left: 12),
      // color: Colors.white,
      // color: Colors.red,
      width: Get.width - 20,
      height: 48.0,
      child: InkWell(
        onTap: () {
          showSearch(
            context: ctx,
            delegate: SearchBarDelegate(
              doSearch: ((query) {
                return ContactRepo().search(kwd: query);
              }),
              searchLabel: 'search'.tr,
              queryTips: 'search_friends_tips'.tr,
              onTapForItem: (value) async {
                if (value is ContactModel) {
                  final repo = ConversationRepo();
                  ConversationModel? obj = await repo.findByPeerId(
                    'C2C',
                    value.peerId,
                  );
                  obj ??= ConversationModel(
                    peerId: value.peerId,
                    avatar: value.avatar,
                    title: value.title,
                    subtitle: '',
                    type: 'C2C',
                    msgType: '',
                    lastMsgId: '',
                    lastTime: 0,
                    lastMsgStatus: 11,
                    // astMsgStatus 10 发送中 sending;  11 已发送 send;
                    unreadNum: 0,
                    isShow: 1,
                    id: 0,
                  );
                  // 保存会话
                  obj = await (ConversationRepo()).save(obj);
                  sendToDialog(Get.context!, obj, 3);
                }
              },
            ),
          );
        },
        child: n.Row([
          FloatingActionButton(
            mini: true,
            // backgroundColor: Colors.white,
            shape: const CircleBorder(),
            elevation: 0,
            tooltip: 'search'.tr,
            onPressed: () {},
            child: Icon(
              Icons.search,
              color: Theme.of(ctx).colorScheme.onPrimary,
              size: 20,
            ),
          ),
          n.Padding(
            left: 0,
            child: Text('search'.tr),
          ),
        ]),
      ),
    );
  }

  /// 分别发送给
  void separatelySendToDialog(List items, int times) {
    List towD = listTo2D(items, 5);
    Get.defaultDialog(
      title: 'send_separately_to'.tr,
      backgroundColor: Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          Get.closeAllDialogs();
        },
        child: Text(
          'button_cancel'.tr,
          textAlign: TextAlign.center,
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          for (var item in state.selects) {
            await logic.sendMsg(item, msg);
          }
          EasyLoading.showSuccess('tip_success'.tr);
          debugPrint("send_to_view callback before ${callback.toString()};");
          if (callback != null) {
            callback!();
          }
          Future.delayed(const Duration(milliseconds: 1600), () {
            Get.closeAllDialogs();
            Get.close();
          });
        },
        child: Text(
          'button_send'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(Get.context!).colorScheme.onPrimary,
          ),
        ),
      ),
      content: SizedBox(
        height: 128.0 * towD.length,
        child: n.Column([
          Expanded(
            child: n.Padding(
              left: 4,
              child: n.Column(
                towD.map<Widget>((row4) {
                  return n.Row(row4.map<Widget>(((item) {
                    return n.Padding(
                      right: 6,
                      top: 6,
                      child: Avatar(
                        imgUri: item.avatar,
                        onTap: () {},
                      ),
                    );
                  })).toList());
                  // ..mainAxisAlignment = MainAxisAlignment.center;
                }).toList(),
              ),
            ),
          ),
          const HorizontalLine(height: 1.0),
          Expanded(
            child: messageMsgWidget(msg),
          ),
        ]),
      ),
    );
  }

  void sendToDialog(BuildContext ctx, ConversationModel model, int times) {
    Get.defaultDialog(
      title: 'send_to'.tr,
      backgroundColor: Get.isDarkMode
          ? const Color.fromRGBO(80, 80, 80, 1)
          : const Color.fromRGBO(240, 240, 240, 1),
      radius: 6,
      cancel: TextButton(
        onPressed: () {
          Get.closeAllDialogs();
        },
        child: Text(
          'button_cancel'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onPrimary,
          ),
        ),
      ),
      confirm: TextButton(
        onPressed: () async {
          bool res = await logic.sendMsg(model, msg);
          if (res) {
            EasyLoading.showSuccess('tip_success'.tr);
            debugPrint(
                "send_to_view callback before 2 ${callback.toString()};");
            if (callback != null) {
              callback!();
            }
            Future.delayed(const Duration(milliseconds: 1600), () {
              Get.closeAllDialogs();
              Get.close();
            });
          } else {
            EasyLoading.showError('tip_failed'.tr);
          }
        },
        child: Text(
          'button_send'.tr,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(ctx).colorScheme.onPrimary,
          ),
        ),
      ),
      content: SizedBox(
        height: 200,
        child: n.Column([
          n.Row([
            Avatar(
              imgUri: model.avatar,
              onTap: () {},
            ),
            Expanded(
              child: n.Padding(
                left: 10,
                child: Text(
                  // 会话对象标题
                  model.title,
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

  Widget _buildListItem(BuildContext context, ConversationModel model) {
    // String susTag = model.getSuspensionTag();
    return n.Column([
      // Offstage(
      //   offstage: model.isSelect != true,
      //   child: _buildSusWidget(susTag),
      // ),
      SizedBox(
        height: _itemHeight.toDouble(),
        child: InkWell(
          onTap: () {
            // debugPrint(" item_onTap multipleChoice ${state.multipleChoice}");
            if (state.multipleChoice.isTrue) {
              // debugPrint(" item_onTap ${model.isSelect}");
              model.selected.value = !model.selected.value;
              if (model.selected.isTrue) {
                state.selects.insert(0, model);
              } else {
                state.selects.remove(model);
              }
              // setState(() {});
            } else {
              sendToDialog(context, model, 2);
            }
          },
          child: n.Row([
            if (state.multipleChoice.isTrue)
              n.Padding(
                right: 8,
                child: Icon(
                  model.selected.isTrue
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.check_mark_circled,
                  color: model.selected.isTrue ? Colors.green : Colors.grey,
                ),
              ),
            Avatar(
              imgUri: model.avatar,
              width: 49,
              height: 49,
            ),
            const Space(),
            Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(right: 30),
                height: _itemHeight.toDouble(),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      width: Get.isDarkMode ? 0.5 : 1.0,
                      color:
                          Theme.of(Get.context!).colorScheme.primaryContainer,
                    ),
                  ),
                ),
                child: Text(
                  model.title,
                  style: const TextStyle(fontSize: 14.0),
                ),
              ),
            ),
          ]),
        ),
      )
    ]);
  }
}
