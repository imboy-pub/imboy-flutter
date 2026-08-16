import 'dart:async';

import 'package:azlistview/azlistview.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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
    // provider 写入必须晚于首帧，否则 Riverpod 抛
    // "Tried to modify a provider while the widget tree was building"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(loadData());
    });
  }

  Future<void> loadData() async {
    final notifier = ref.read(addMemberProvider.notifier);
    notifier.setLoading(true);
    try {
      // 加载群成员列表
      List<GroupMemberModel> list = await (GroupMemberRepo()).page(
        limit: 2000,
        where: "${GroupMemberRepo.groupId} = ?",
        whereArgs: [widget.groupId],
      );

      notifier.setGroupMemberList(list);

      // 联系人**不能**走 contactProvider 的 state 取：它是 @riverpod（autoDispose），
      // 本页只 read 不 watch，读完实例就被回收 —— loadData() 写进去的数据落在一个
      // 已被丢弃的实例上，await 之后再 read 拿到的是全新空状态，于是"添加成员"
      // 永远显示「暂无数据」（本页因 BUG#102 长期不可达，这个空列表一直没被发现）。
      //
      // 直接读本地库：既不受 provider 生命周期影响，返回的也都是真实好友，
      // 不含 contactList 里混的 6 个功能入口占位（朋友圈/找附近的人/AI 助手广场…）。
      List<ContactModel> contacts = await ContactRepo().findFriend();
      if (contacts.isEmpty) {
        // 本地还没同步过（如新装后直接进本页）：借 contactProvider 触发一次
        // 服务端同步，同步结果落库，再从库里读。
        await ref.read(contactProvider.notifier).loadData();
        contacts = await ContactRepo().findFriend();
      }
      notifier.handleContactList(contacts);
    } finally {
      notifier.setLoading(false);
    }
  }

  Widget _buildListItem(BuildContext context, ContactModel model) {
    final isMember = ref
        .read(addMemberProvider.notifier)
        .isMember(model.peerId);
    final isSelected = model.selected;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.tiny,
      ),
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
      // 多选页必须声明 selected：读屏用户听到名字但不知道自己选没选。
      // 已是群成员的行不可选，用 enabled: false 让读屏读出"已停用"，
      // 否则用户会一直点一个永远没反应的行。
      // 名字由 Text 自带语义提供，此处不重复设 label（避免双标签重复朗读）。
      child: Semantics(
        button: true,
        enabled: !isMember,
        selected: isSelected,
        child: GestureDetector(
          // 不用 InkWell：DESIGN.md §13.2 禁止 Cupertino 列表行用 Material Ripple
          behavior: HitTestBehavior.opaque,
          onTap: isMember
              ? null
              : () {
                  ref
                      .read(addMemberProvider.notifier)
                      .toggleSelection(model, widget.groupId);
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.regular,
              vertical: AppSpacing.small,
            ),
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
                        : AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.medium),
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
                          : AppColors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Avatar(imgUri: model.avatar, width: 44, height: 44),
                ),
                const SizedBox(width: AppSpacing.medium),
                // 姓名和状态
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        model.title,
                        style: context.textStyle(
                          FontSizeType.large,
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
                          t.chat.alreadyMember,
                          style: context.textStyle(
                            FontSizeType.small,
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
                      horizontal: AppSpacing.small,
                      vertical: AppSpacing.tiny,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: AppRadius.borderRadiusMedium,
                    ),
                    child: Text(
                      t.main.selected,
                      style: context.textStyle(
                        FontSizeType.tiny,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
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
          tooltip: t.common.buttonCancel,
          icon: Icon(
            CupertinoIcons.xmark,
            color: Theme.of(context).colorScheme.onSurface,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: t.common.selectContacts,
        rightDMActions: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: state.selects.isNotEmpty
                ? () async {
                    AppLoading.show(status: t.common.loading);
                    int memberCount = state.selects.length;
                    iPrint("selects $memberCount");
                    bool res = await ref
                        .read(addMemberProvider.notifier)
                        .joinGroup(widget.groupId, state.selects);
                    AppLoading.dismiss();
                    if (res && context.mounted) {
                      ref.read(addMemberProvider.notifier).resetData();
                      Navigator.of(context).pop();
                    }
                  }
                : null,
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
      body: Column(
        children: [
          // 选择提示区域
          state.selects.isNotEmpty
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.regular,
                    vertical: AppSpacing.small,
                  ),
                  padding: const EdgeInsets.all(AppSpacing.medium),
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
                      const SizedBox(width: AppSpacing.small),
                      Text(
                        t.main.selectedCount(count: '${state.selects.length}'),
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
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
              ),
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
                    return state.isLoading
                        ? const Center(child: CupertinoActivityIndicator())
                        : state.contactItems.isEmpty
                        ? NoDataView(text: t.common.noData)
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
                              downTextStyle: context.textStyle(
                                FontSizeType.small,
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
