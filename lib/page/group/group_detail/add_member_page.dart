import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart' show FontSizeType;

import 'add_member_provider.dart';

/// 添加群成员页面
class AddMemberPage extends ConsumerStatefulWidget {
  final String groupId;

  const AddMemberPage({super.key, required this.groupId});

  @override
  ConsumerState<AddMemberPage> createState() => AddMemberPageState();
}

class AddMemberPageState extends ConsumerState<AddMemberPage> {
  @override
  void initState() {
    super.initState();
    loadData();
  }

  void loadData() async {
    final notifier = ref.read(addMemberProvider.notifier);

    // 加载群成员列表
    List<GroupMemberModel> list = await (GroupMemberRepo()).page(
      limit: 2000,
      where: "${GroupMemberRepo.groupId} = ?",
      whereArgs: [widget.groupId],
    );

    notifier.setGroupMemberList(list);

    // 加载联系人列表
    // TODO: 从联系人 repository 加载
    // notifier.handleContactList(contacts);
  }

  Widget _buildListItem(BuildContext context, ContactModel model) {
    final isMember = ref
        .read(addMemberProvider.notifier)
        .isMember(model.peerId);
    final isSelected = model.selected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: isMember
              ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)
              : isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: isMember
            ? null
            : () {
                ref
                    .read(addMemberProvider.notifier)
                    .toggleSelection(model, widget.groupId);
              },
        borderRadius: AppRadius.borderRadiusMedium,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              // 选择图标
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMember
                      ? Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.2)
                      : isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                ),
                child: Icon(
                  isMember
                      ? CupertinoIcons.check_mark_circled_solid
                      : isSelected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.check_mark_circled,
                  size: 16,
                  color: isMember
                      ? Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.6)
                      : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              // 头像
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isMember
                        ? Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.3)
                        : isSelected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.5)
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Avatar(imgUri: model.avatar, width: 44, height: 44),
              ),
              const SizedBox(width: 12),
              // 姓名和状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      model.title,
                      style: TextStyle(
                        fontSize: FontSizeType.large.size,
                        color: isMember
                            ? Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isMember) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.alreadyMember,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // 选中状态指示器
              if (isSelected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Text(
                    t.selected,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addMemberProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: t.selectContacts,
        rightDMActions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton(
                onPressed: state.selects.isNotEmpty
                    ? () async {
                        EasyLoading.show(status: t.loading);
                        int memberCount = state.selects.length;
                        iPrint(
                          "selects $memberCount ${state.selects.map((e) => e.toJson()).toList()}",
                        );
                        bool res = await ref
                            .read(addMemberProvider.notifier)
                            .joinGroup(widget.groupId, state.selects);
                        EasyLoading.dismiss();
                        if (res && mounted) {
                          ref.read(addMemberProvider.notifier).resetData();
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: state.selects.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  foregroundColor: state.selects.isNotEmpty
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.outline,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.borderRadiusLarge,
                  ),
                  elevation: state.selects.isNotEmpty ? 2 : 0,
                ),
                child: Text(
                  '${t.buttonAccomplish}${state.selectsTips}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 选择提示区域
          state.selects.isNotEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusMedium,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        t.selectedCount(count: '${state.selects.length}'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),

          // 联系人列表区域
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: AppRadius.borderRadiusRegular,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.1),
                ),
              ),
              child: SlidableAutoCloseBehavior(
                child: Builder(
                  builder: (context) {
                    return state.contactItems.isEmpty
                        ? NoDataView(text: t.noData)
                        : AzListView(
                            data: state.contactItems,
                            itemCount: state.contactItems.length,
                            itemBuilder: (BuildContext context, int index) {
                              ContactModel model = state.contactItems[index];
                              return _buildListItem(context, model);
                            },
                            physics: const AlwaysScrollableScrollPhysics(),
                            susItemBuilder: (BuildContext context, int index) {
                              ContactModel model = state.contactItems[index];
                              if ('↑' == model.getSuspensionTag()) {
                                return Container();
                              }
                              return Container();
                            },
                            indexBarData: state.contactItems.isNotEmpty
                                ? ['↑', ...state.currIndexBarData]
                                : [],
                            indexBarOptions: IndexBarOptions(
                              needRebuild: true,
                              ignoreDragCancel: true,
                              downTextStyle: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              downItemDecoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              indexHintWidth: 64,
                              indexHintHeight: 64,
                              indexHintDecoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.8),
                                borderRadius: AppRadius.borderRadiusSmall,
                              ),
                              indexHintAlignment: Alignment.centerRight,
                              indexHintChildAlignment: const Alignment(
                                -0.25,
                                0.0,
                              ),
                              indexHintOffset: const Offset(-20, 0),
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
