import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/button.dart';
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
    unawaited(initData());
  }

  Future<void> initData() async {
    final notifier = ref.read(removeMemberProvider.notifier);
    final currentUid = UserRepoLocal.to.currentUid;

    List<GroupMemberModel> list = await (GroupMemberRepo()).page(
      limit: 2000,
      where: "${GroupMemberRepo.groupId} = ?",
      whereArgs: [widget.groupId],
    );

    notifier.setGroupMemberList(list, currentUid);

    iPrint("remove_member_page/loadData ${widget.groupId} ${list.length}");
  }

  Widget _buildListItem(BuildContext context, GroupMemberModel model) {
    final notifier = ref.read(removeMemberProvider.notifier);
    final isSelected = notifier.isSelected(model);

    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          child: InkWell(
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
                          color: Theme.of(context).colorScheme.primaryContainer,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            model.alias.isEmpty ? model.nickname : model.alias,
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
          RoundedElevatedButton(
            text: '${t.common.buttonAccomplish}${state.selectsTips}',
            highlighted: state.selects.isNotEmpty,
            onPressed: () async {
              if (state.selects.isEmpty) {
                return;
              }
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
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: state.groupMemberList.isEmpty
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
