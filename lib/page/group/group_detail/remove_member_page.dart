import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
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
                  padding: const EdgeInsets.only(left: 16, right: 8),
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
                const SizedBox(width: 8),
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
                            style: TextStyle(
                              fontSize: 14.0,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: IconButton(
                            icon: Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                            ),
                            padding: const EdgeInsets.only(left: 8, right: 8),
                            onPressed: () {
                              context.push(
                                '/people_info',
                                extra: {
                                  'id': model.userId,
                                  'scene': 'group_member',
                                },
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
        title: t.removeMember,
        leading: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextButton(
            onPressed: () {
              context.pop();
            },
            child: Text(
              t.buttonCancel,
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ),
        rightDMActions: <Widget>[
          RoundedElevatedButton(
            text: '${t.buttonAccomplish}${state.selectsTips}',
            highlighted: state.selects.isNotEmpty,
            onPressed: () async {
              if (state.selects.isEmpty) {
                return;
              }
              EasyLoading.show(status: t.loading);
              int memberCount = state.selects.length;
              iPrint("selects $memberCount");
              bool res = await ref
                  .read(removeMemberProvider.notifier)
                  .removeMembers(widget.groupId);
              EasyLoading.dismiss();
              if (res && mounted) {
                context.pop(state.selects);
              } else {
                EasyLoading.showError(t.tipFailed);
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      color: Theme.of(context).colorScheme.surface,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Expanded(
                            child: state.groupMemberList.isEmpty
                                ? NoDataView(text: t.noData)
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: state.groupMemberList.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                          GroupMemberModel model =
                                              state.groupMemberList[index];
                                          return _buildListItem(context, model);
                                        },
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
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
