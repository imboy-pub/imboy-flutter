import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'launch_chat_provider.dart';

/// 发起聊天页面
class LaunchChatPage extends ConsumerStatefulWidget {
  const LaunchChatPage({super.key});

  @override
  ConsumerState<LaunchChatPage> createState() => _LaunchChatPageState();
}

class _LaunchChatPageState extends ConsumerState<LaunchChatPage> {
  final int _itemHeight = 60;

  @override
  void initState() {
    super.initState();
    // 延迟加载联系人列表，避免在 build 过程中调用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(launchChatProvider.notifier).loadContacts();
    });
  }

  /// 构建联系人列表项 - 使用优化后的主题样式
  Widget _buildListItem(BuildContext context, ContactModel model) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final state = ref.watch(launchChatProvider);

    // 检查是否已选中
    final isSelected = state.selects.any((s) => s.peerId == model.peerId);

    return Column(
      children: [
        Container(
          height: _itemHeight.toDouble(),
          color: isDark ? colorScheme.surface : Colors.white,
          child: InkWell(
            onTap: () {
              debugPrint(" item_onTap $isSelected");
              ref.read(launchChatProvider.notifier).toggleSelection(model);
            },
            child: Row(
              children: [
                // 选择状态图标 - 使用优化后的主题色
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Icon(
                    isSelected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: isSelected
                        ? AppColors.primary
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
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(launchChatProvider);
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
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: RoundedElevatedButton(
              text: '${t.buttonAccomplish}${state.selectsTips}',
              highlighted: state.selects.isNotEmpty,
              onPressed: () async {
                EasyLoading.show(status: t.loading);
                int memberCount = state.selects.length;
                iPrint(
                  "state.selects $memberCount ${state.selects.map((e) => e.toJson()).toList()}",
                );
                try {
                  GroupModel? m = await ref
                      .read(launchChatProvider.notifier)
                      .groupAdd(state.selects);
                  if (m != null) {
                    EasyLoading.dismiss();
                    ref.read(launchChatProvider.notifier).resetData();
                    if (context.mounted) {
                      context.push(
                        '/chat',
                        extra: {
                          'peerId': m.groupId,
                          'type': 'C2G',
                          'peerTitle': m.title,
                          'peerAvatar': m.avatar,
                          'peerSign': '',
                          'memberCount': memberCount + 1,
                        },
                      );
                    }
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
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
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
                      context.push('/group/select');
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
                      context.push('/group/face_to_face');
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
                child: Builder(
                  builder: (context) {
                    return state.items.isEmpty
                        ? NoDataView(text: t.noData)
                        : AzListView(
                            data: state.items,
                            itemCount: state.items.length,
                            itemBuilder: (BuildContext context, int index) {
                              ContactModel model = state.items[index];
                              return _buildListItem(context, model);
                            },
                            physics: const AlwaysScrollableScrollPhysics(),
                            susItemBuilder: (BuildContext context, int index) {
                              ContactModel model = state.items[index];
                              if ('↑' == model.getSuspensionTag()) {
                                return Container();
                              }
                              return Container();
                            },
                            indexBarData: state.items.isNotEmpty
                                ? ['↑', ...state.currIndexBarData]
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
                                color: AppColors.primary,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              indexHintWidth: 64,
                              indexHintHeight: 64,
                              indexHintDecoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.9),
                                borderRadius: AppRadius.borderRadiusSmall,
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
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
