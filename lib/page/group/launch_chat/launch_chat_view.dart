import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_view.dart';
import 'package:imboy/page/group/group_select/group_select_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'launch_chat_logic.dart';
import 'launch_chat_state.dart';
import 'package:imboy/i18n/strings.g.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          height: _itemHeight.toDouble(),
          color: isDark ? colorScheme.surface : Colors.white,
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
                    padding: const EdgeInsets.only(left: 16, right: 12),
                    child: Icon(
                      model.selected.isTrue
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle,
                      color: model.selected.isTrue
                          ? AppColors.primaryGreen
                          : colorScheme.outline.withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                  // 用户头像
                  Avatar(imgUri: model.avatar, width: 40, height: 40),
                  const SizedBox(width: 12),
                  // 用户信息区域 - 使用优化后的主题样式
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(right: 30),
                      height: _itemHeight.toDouble(),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 0.5,
                            color: colorScheme.outline.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      child: Text(
                        model.title,
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.onSurface,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: t.selectContacts,
        leadingWidth: 72,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              t.buttonCancel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          Obx(
            () => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: RoundedElevatedButton(
                text: '${t.buttonAccomplish}${logic.state.selectsTips.value}',
                highlighted: logic.state.selects.isNotEmpty,
                onPressed: () async {
                  EasyLoading.show(status: t.loading);
                  int memberCount = logic.state.selects.length;
                  iPrint(
                    "logic.state.selects $memberCount ${logic.state.selects.toJson()}",
                  );
                  try {
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
                    } else {
                      EasyLoading.dismiss();
                      EasyLoading.showError(t.tipFailed);
                    }
                  } catch (e) {
                    EasyLoading.dismiss();
                    EasyLoading.showError('${t.tipFailed}: $e');
                    debugPrint("groupAdd error: $e");
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部功能入口
          Container(
            margin: const EdgeInsets.only(top: 16, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? colorScheme.shadow.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 选择群聊选项
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      t.selectAGroup,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onTap: () {
                      Get.to(
                        () => GroupSelectPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    indent: 16,
                    endIndent: 16,
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  // 面对面建群选项
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      t.createGroupF2f,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    onTap: () {
                      Get.to(
                        () => FaceToFacePage(),
                        transition: Transition.rightToLeft,
                        popGesture: true,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 联系人列表
          Expanded(
            child: Container(
              color: isDark ? colorScheme.surface : Colors.white,
              child: SlidableAutoCloseBehavior(
                child: Obx(() {
                  return logic.state.items.isEmpty
                      ? NoDataView(text: t.noData)
                      : AzListView(
                          data: logic.state.items,
                          itemCount: logic.state.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            ContactModel model = logic.state.items[index];
                            return _buildListItem(context, model);
                          },
                          physics: const AlwaysScrollableScrollPhysics(),
                          susItemBuilder: (BuildContext context, int index) {
                            ContactModel model = logic.state.items[index];
                            if ('↑' == model.getSuspensionTag()) {
                              return Container();
                            }
                            return Get.find<ContactLogic>().getSusItem(
                              context,
                              model.getSuspensionTag(),
                            );
                          },
                          indexBarData: logic.state.items.isNotEmpty
                              ? ['↑', ...logic.state.currIndexBarData]
                              : [],
                          indexBarOptions: IndexBarOptions(
                            needRebuild: true,
                            ignoreDragCancel: true,
                            downTextStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            downItemDecoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indexHintWidth: 64,
                            indexHintHeight: 64,
                            indexHintDecoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            indexHintTextStyle: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            indexHintAlignment: Alignment.centerRight,
                            indexHintChildAlignment: const Alignment(0, 0),
                            indexHintOffset: const Offset(-20.0, 0),
                          ),
                        );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
