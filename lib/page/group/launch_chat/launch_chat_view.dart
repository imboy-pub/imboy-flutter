import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';
import 'package:imboy/page/group/group_select/group_select_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'launch_chat_logic.dart';
import 'launch_chat_state.dart';

/// 发起聊天页面
class LaunchChatPage extends StatelessWidget {
  final LaunchChatLogic logic = Get.put(LaunchChatLogic());
  final LaunchChatState state = Get.find<LaunchChatLogic>().state;

  final int _itemHeight = 60;

  LaunchChatPage({super.key});

  void loadData() async {
    logic.listFriend();
  }

  /// 构建联系人列表项 - 使用优化后的主题样式
  Widget _buildListItem(BuildContext context, ContactModel model) {
    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          child: Obx(
            () => InkWell(
              onTap: () {
                debugPrint(" item_onTap ${model.selected}");
                model.selected.value = !model.selected.value;
                if (model.selected.isTrue) {
                  state.selects.insert(0, model);
                } else {
                  state.selects.remove(model);
                }
                if (state.selects.value.isNotEmpty) {
                  state.selectsTips.value = '(${state.selects.value.length})';
                } else {
                  state.selectsTips.value = '';
                }
              },
              child: Row(
                children: [
                  // 选择状态图标 - 使用优化后的主题色
                  Padding(
                    padding: const EdgeInsets.only(left: 8, right: 8),
                    child: Icon(
                      model.selected.isTrue
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.check_mark_circled,
                      color: model.selected.isTrue
                          ? ThemeManager.instance.getThemeColor('primary')
                          : ThemeManager.instance.getThemeColor('outline'),
                    ),
                  ),
                  // 用户头像
                  Avatar(imgUri: model.avatar, width: 49, height: 49),
                  const Space(),
                  // 用户信息区域 - 使用优化后的主题样式
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(right: 30),
                      height: _itemHeight.toDouble(),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: context.themeManager.isDarkMode ? 0.5 : 1.0,
                            color: context
                                .themeColor('outline')
                                .withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Text(
                        model.title,
                        style: ThemeManager.instance.getTextStyle(
                          FontSizeType.normal,
                          color: ThemeManager.instance.getThemeColor('onSurface'),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    loadData();
    return Scaffold(
      backgroundColor: ThemeManager.instance.getThemeColor('surface'),
      appBar: NavAppBar(
        title: 'select_contacts'.tr,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'button_cancel'.tr,
              textAlign: TextAlign.center,
              style: ThemeManager.instance.getTextStyle(
                FontSizeType.normal,
                color: ThemeManager.instance.getThemeColor('primary'),
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          Obx(
            () => RoundedElevatedButton(
              text: '${'button_accomplish'.tr}${logic.state.selectsTips.value}',
              highlighted: logic.state.selects.isNotEmpty,
              onPressed: () async {
                EasyLoading.show(status: 'loading'.tr);
                int memberCount = logic.state.selects.length;
                iPrint(
                  "logic.state.selects $memberCount ${logic.state.selects.toJson()}",
                );
                GroupModel? m = await logic.groupAdd(logic.state.selects.value);
                if (m != null) {
                  EasyLoading.dismiss();
                  logic.resetData();
                  Get.to(
                    () => ChatPage(
                      peerId: m.groupId,
                      type: 'C2G',
                      peerTitle: m.title,
                      peerAvatar: m.avatar,
                      peerSign: '',
                      options: {'memberCount': memberCount + 1},
                    ),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  );
                }
              },
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /* TODO leeyi 2024-04-12 00:05:34 搜索功能
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 0, right: 8, bottom: 10),
                    child: searchBar(
                      context,
                      searchLabel: 'search'.tr,
                      hintText: 'search'.tr,
                      queryTips: '',
                      doSearch: ((query) async {
                        debugPrint("launch_chat_view doSearch ${query.toString()}");
                        List<ContactModel> li = await ContactRepo().search(kwd: query);
                        return li;
                      }),
                      onTapForItem: (value) {
                        debugPrint("launch_chat_view value ${value is ContactModel}, ${value.toString()}");
                        if (value is ContactModel) {
                          // 处理搜索结果点击
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            */
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: Get.width,
                      height: Get.height - 150,
                      color: ThemeManager.instance.getThemeColor('surface'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 选择群聊选项 - 使用优化后的主题样式
                          ListTile(
                            title: Text(
                              'select_a_group'.tr,
                              style: ThemeManager.instance.getTextStyle(
                                FontSizeType.normal,
                                color: ThemeManager.instance.getThemeColor('onSurface'),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              navigateNextIcon.icon,
                              color: ThemeManager.instance.getThemeColor('outline'),
                            ),
                            onTap: () {
                              Get.to(
                                () => GroupSelectPage(),
                                transition: Transition.rightToLeft,
                                popGesture: true, // 右滑，返回上一页
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Divider(
                              color: context
                                  .themeColor('outline')
                                  .withValues(alpha: 0.2),
                              height: 1,
                            ),
                          ),
                          // 面对面建群选项 - 使用优化后的主题样式
                          ListTile(
                            title: Text(
                              'create_group_f2f'.tr,
                              style: ThemeManager.instance.getTextStyle(
                                FontSizeType.normal,
                                color: ThemeManager.instance.getThemeColor('onSurface'),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              navigateNextIcon.icon,
                              color: ThemeManager.instance.getThemeColor('outline'),
                            ),
                            onTap: () {
                              Get.to(
                                () => FaceToFacePage(),
                                transition: Transition.rightToLeft,
                                popGesture: true, // 右滑，返回上一页
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 18),
                            child: Divider(
                              color: context
                                  .themeColor('outline')
                                  .withValues(alpha: 0.2),
                              height: 1,
                            ),
                          ),
                          // 联系人列表 - 使用优化后的主题样式
                          Expanded(
                            child: SlidableAutoCloseBehavior(
                              child: Obx(() {
                                return logic.state.items.isEmpty
                                    ? NoDataView(text: 'no_data'.tr)
                                    : AzListView(
                                        data: logic.state.items,
                                        itemCount: logic.state.items.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                              ContactModel model =
                                                  logic.state.items[index];
                                              return _buildListItem(
                                                context,
                                                model,
                                              );
                                            },
                                        // 解决联系人数据量少的情况下无法刷新的问题
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        susItemBuilder:
                                            (BuildContext context, int index) {
                                              ContactModel model =
                                                  logic.state.items[index];
                                              if ('↑' ==
                                                  model.getSuspensionTag()) {
                                                return Container();
                                              }
                                              return Get.find<ContactLogic>()
                                                  .getSusItem(
                                                    context,
                                                    model.getSuspensionTag(),
                                                  );
                                            },
                                        indexBarData:
                                            logic.state.items.isNotEmpty
                                            ? [
                                                '↑',
                                                ...logic.state.currIndexBarData,
                                              ]
                                            : [],
                                        indexBarOptions: IndexBarOptions(
                                          needRebuild: true,
                                          ignoreDragCancel: true,
                                          // 使用优化后的主题色和字体
                                          downTextStyle: TextStyle(
                                            fontSize: 12,
                                            color: context.themeColor(
                                              'onPrimary',
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          downItemDecoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: context.themeColor(
                                              'primary',
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: context
                                                    .themeColor('primary')
                                                    .withValues(alpha: 0.3),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          indexHintWidth: 64,
                                          indexHintHeight: 64,
                                          indexHintDecoration: BoxDecoration(
                                            color: context
                                                .themeColor('primary')
                                                .withValues(alpha: 0.9),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.1,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          indexHintTextStyle: TextStyle(
                                            fontSize: 24,
                                            color: context.themeColor(
                                              'onPrimary',
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                          indexHintAlignment:
                                              Alignment.centerRight,
                                          indexHintChildAlignment:
                                              const Alignment(0, 0),
                                          indexHintOffset: const Offset(
                                            -20.0,
                                            0,
                                          ),
                                        ),
                                      );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
