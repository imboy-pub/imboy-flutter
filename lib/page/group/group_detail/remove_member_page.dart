import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'remove_member_provider.dart';

/// 移除群成员页面
class RemoveMemberPage extends ConsumerStatefulWidget {
  final String groupId;

  const RemoveMemberPage({super.key, required this.groupId});

  @override
  ConsumerState<RemoveMemberPage> createState() => RemoveMemberPageState();
}

class RemoveMemberPageState extends ConsumerState<RemoveMemberPage> {
  final int _itemHeight = 60;

  @override
  void initState() {
    super.initState();
    // provider 写入必须晚于首帧，否则 Riverpod 抛
    // "Tried to modify a provider while the widget tree was building"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(initData());
    });
  }

  Future<void> initData() async {
    final notifier = ref.read(removeMemberProvider.notifier);
    final currentUid = UserRepoLocal.to.currentUid;
    notifier.setLoading(true);
    try {
      List<GroupMemberModel> list = await (GroupMemberRepo()).page(
        limit: 2000,
        where: "${GroupMemberRepo.groupId} = ?",
        whereArgs: [widget.groupId],
      );

      notifier.setGroupMemberList(list, currentUid);

      iPrint("remove_member_page/loadData ${widget.groupId} ${list.length}");
    } finally {
      notifier.setLoading(false);
    }
  }

  Widget _buildListItem(BuildContext context, GroupMemberModel model) {
    final notifier = ref.read(removeMemberProvider.notifier);
    final isSelected = notifier.isSelected(model);

    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          // 多选页必须声明 selected：读屏用户听到名字但不知道选没选。
          // 移除成员是破坏性操作，选中态读不出来风险更高。
          // 名字由 Text 自带语义提供，此处不重复设 label。
          child: Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              // 不用 InkWell：DESIGN.md §13.2 禁止 Cupertino 列表行用 Ripple
              behavior: HitTestBehavior.opaque,
              onTap: () {
                notifier.toggleSelection(model);
              },
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.regular,
                      right: AppSpacing.small,
                    ),
                    child: Icon(
                      isSelected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.check_mark_circled,
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Avatar(imgUri: model.avatar, width: 49, height: 49),
                  const SizedBox(width: AppSpacing.small),
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerLeft,
                      height: _itemHeight.toDouble(),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.borderRadiusMedium,
                        border: Border(
                          top: BorderSide(
                            width: 0.5,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              model.alias.isEmpty
                                  ? model.nickname
                                  : model.alias,
                              style: context.textStyle(
                                FontSizeType.normal,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: IconButton(
                              tooltip: t.channel.viewProfile,
                              icon: Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                              ),
                              padding: const EdgeInsets.only(
                                left: AppSpacing.small,
                                right: AppSpacing.small,
                              ),
                              onPressed: () {
                                // 路由 /people_info/:id 通过 pathParameters 解析 id，
                                // scene 走 queryParameters；extra 在该路由 builder 中不会被读取。
                                context.push(
                                  '/people_info/${model.userId}?scene=group_member',
                                );
                              },
                            ),
                          ),
                        ],
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
    final state = ref.watch(removeMemberProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        title: t.common.removeMember,
        leading: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.small),
          child: TextButton(
            onPressed: () {
              context.pop();
            },
            child: Text(
              t.common.buttonCancel,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: state.selects.isEmpty
                ? null
                : () async {
                    AppLoading.show(status: t.common.loading);
                    int memberCount = state.selects.length;
                    iPrint("selects $memberCount");
                    bool res = await ref
                        .read(removeMemberProvider.notifier)
                        .removeMembers(widget.groupId);
                    AppLoading.dismiss();
                    if (res && context.mounted) {
                      context.pop(state.selects);
                    } else {
                      AppLoading.showError(t.common.tipFailed);
                    }
                  },
            child: Text(
              '${t.common.buttonAccomplish}${state.selectsTips}',
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: state.selects.isNotEmpty
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: state.selects.isNotEmpty
                    ? AppColors.getIosBlue(Theme.of(context).brightness)
                    : AppColors.iosGray,
              ),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : state.groupMemberList.isEmpty
          ? NoDataView(text: t.common.noData)
          : ListView.builder(
              itemCount: state.groupMemberList.length,
              itemBuilder: (BuildContext context, int index) {
                GroupMemberModel model = state.groupMemberList[index];
                return _buildListItem(context, model);
              },
              physics: const AlwaysScrollableScrollPhysics(),
            ),
    );
  }
}
