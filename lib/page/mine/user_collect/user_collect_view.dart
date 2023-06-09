import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectPage extends StatelessWidget {
  UserCollectPage({super.key});

  int page = 1;
  int size = 20;
  final logic = Get.put(UserCollectLogic());
  final state = Get.find<UserCollectLogic>().state;

  void initData() async {
    var list = await logic.page(page: page, size: size);
    state.items.value = list;
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '我的收藏'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.ChatBg,
          child: n.Column(
            [
              n.Padding(
                left: 8,
                top: 10,
                right: 8,
                bottom: 10,
                child: SearchBar(
                  hintText: '搜索'.tr,
                  // isBorder: true,
                  onTap: () {
                    showSearch(
                      context: context,
                      // useRootNavigator: true,
                      delegate: LocalSearchBarDelegate(
                        searchLabel: '搜索'.tr,
                        queryTips: '收藏人名、群名、标签等'.tr,
                        doSearch: ((query) {
                          // debugPrint(
                          //     "> on search doSearch ${query.toString()}");
                          return UserCollectRepo().search(kwd: query);
                        }),
                        onTapForItem: (value) {
                          // debugPrint(
                          //     "> on search value ${value is UserCollectModel}, ${value.toString()}");
                          if (value is UserCollectModel) {
                            // Get.to(
                            //   () => PeopleInfoPage(
                            //     id: value.deniedUid,
                            //     sence: 'denylist',
                            //   ),
                            //   transition: Transition.rightToLeft,
                            //   popGesture: true, // 右滑，返回上一页
                            // );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: SlidableAutoCloseBehavior(child: Obx(() {
                  return state.items.isEmpty
                      ? NoDataView(text: '暂无数据'.tr)
                      : n.Padding(
                          top: 16,
                          left: 10,
                          right: 10,
                          child: ListView.builder(
                            itemCount: state.items.length,
                            itemBuilder: (BuildContext context, int index) {
                              UserCollectModel obj = state.items[index];
                              Widget body = const Spacer();
                              String type =
                                  obj.info['payload']['msg_type'] ?? '';
                              if (type == 'text') {
                                body = Expanded(
                                  child: Text(
                                    obj.info['payload']['text'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 18.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                                    maxLines: 8,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }
                              return Slidable(
                                key: ValueKey(obj.kindId),
                                groupTag: '0',
                                closeOnScroll: true,
                                endActionPane: ActionPane(
                                  extentRatio: 0.5,
                                  motion: const StretchMotion(),
                                  children: [
                                    // SlidableAction(
                                    //   key: ValueKey("hide_$index"),
                                    //   flex: 2,
                                    //   backgroundColor: Colors.amber,
                                    //   onPressed: (_) async {
                                    //     // await logic
                                    //     //     .hideConversation(model.peerId);
                                    //     // logic.update([
                                    //     //   logic.conversations.removeAt(index),
                                    //     //   logic.conversationRemind[
                                    //     //       model.peerId] = 0,
                                    //     //   logic.chatMsgRemindCounter,
                                    //     // ]);
                                    //   },
                                    //   label: "".tr,
                                    //   spacing: 1,
                                    // ),
                                    SlidableAction(
                                      key: ValueKey("delete_$index"),
                                      flex: 1,
                                      backgroundColor: Colors.red,
                                      // foregroundColor: Colors.white,
                                      onPressed: (_) async {
                                        // await logic.removeConversation(
                                        //     conversationId);
                                        // logic.update([
                                        //   logic.conversations.removeAt(index),
                                        //   logic.conversationRemind[
                                        //       model.peerId] = 0,
                                        //   logic.chatMsgRemindCounter,
                                        // ]);
                                      },
                                      label: "删除".tr,
                                      spacing: 1,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: n.Column([
                                    n.Row([body]),
                                    n.Row(const [SizedBox(height: 16)]),
                                    n.Row([
                                      Text(
                                        // 会话对象标题
                                        obj.source,
                                        style: const TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Expanded(child: SizedBox()),
                                      Text(
                                        DateTimeHelper.lastTimeFmt(
                                            obj.createdAt),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.MainTextColor,
                                          fontSize: 14.0,
                                        ),
                                      ),
                                    ])
                                      ..mainAxisAlignment =
                                          MainAxisAlignment.spaceBetween,
                                  ]),
                                ),
                              );
                            },
                          ),
                        );
                })),
              ),
            ],
            mainAxisSize: MainAxisSize.min,
          ),
        ),
      ),
    );
  }
}
