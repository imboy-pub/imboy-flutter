import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// W10（F17/J19.b）：群主「转让后退出」的合格接任人单选页。
///
/// 单选（一次转让给一人）；排除自己；确认后把选中 uid pop 回调用方，
/// 转让/退出编排由调用方执行（分步结果准确，见 GroupDangerZone）。
/// 复用 remove_member_page 的行渲染约定：不用 Material Ripple（DESIGN.md
/// §13.2 禁止 Cupertino 列表行）、选中态对读屏可见。
class TransferOwnerPage extends StatefulWidget {
  const TransferOwnerPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<TransferOwnerPage> createState() => _TransferOwnerPageState();
}

class _TransferOwnerPageState extends State<TransferOwnerPage> {
  final int _itemHeight = 60;
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    // provider/DB 写入必须晚于首帧（Riverpod/构建期限制，同款防坑）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_loadMembers());
    });
  }

  Future<void> _loadMembers() async {
    final currentUid = UserRepoLocal.to.currentUid;
    // 排除自己：接任人必须是其他成员；只看在册成员行。
    final list = await GroupMemberRepo().page(
      limit: 2000,
      where:
          "${GroupMemberRepo.groupId} = ? AND ${GroupMemberRepo.userId} != ?",
      whereArgs: [widget.groupId, currentUid],
    );
    if (!mounted) return;
    setState(() {
      _members = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        title: t.group.transferAndLeave,
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator())
                  : _members.isEmpty
                  ? Center(child: Text(t.group.noEligibleSuccessor))
                  : ListView.builder(
                      itemCount: _members.length,
                      itemBuilder: (context, index) =>
                          _buildListItem(context, _members[index]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  borderRadius: BorderRadius.circular(14),
                  color: _selectedUid == null
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.primary,
                  onPressed: _selectedUid == null
                      ? null
                      : () => Navigator.of(context).pop(_selectedUid),
                  child: Text(
                    t.common.buttonConfirm,
                    style: context.textStyle(
                      FontSizeType.body,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem(BuildContext context, GroupMemberModel model) {
    final uid = model.userId.toString();
    final isSelected = uid == _selectedUid;
    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          child: Semantics(
            button: true,
            selected: isSelected,
            child: GestureDetector(
              // 不用 InkWell：DESIGN.md §13.2 禁止 Cupertino 列表行用 Ripple
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedUid = uid),
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
                          : CupertinoIcons.circle,
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
                            color: Theme.of(context)
                                .colorScheme
                                .primaryContainer,
                          ),
                        ),
                      ),
                      child: Text(
                        model.alias.isNotEmpty ? model.alias : model.nickname,
                        style: context.textStyle(FontSizeType.subheadline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
}
