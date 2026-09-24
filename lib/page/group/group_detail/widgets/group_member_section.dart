import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/ui/avatar_list.dart' show AvatarList;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_member_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

import '../group_detail_provider.dart';

/// 群成员 Section：独立 ConsumerWidget，只 select memberCount/memberList，
/// 避免 GroupDetailPage 其余字段变化（如 myGroupAlias/title）连带重建
/// 头像列表布局。
///
/// ENT-APP-02 等价拆分：自 group_detail_page.dart `_GroupMemberSection`
/// 机械搬运（仅类名 public 化），行为与 widget 树逐层一致。
class GroupMemberSection extends ConsumerWidget {
  const GroupMemberSection({
    super.key,
    required this.groupId,
    required this.onMemberRemoved,
  });

  final String groupId;
  final VoidCallback onMemberRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberCount = ref.watch(
      groupDetailProvider.select((s) => s.memberCount),
    );
    final memberList = ref.watch(
      groupDetailProvider.select((s) => s.memberList),
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.regular,
        AppSpacing.small,
        AppSpacing.regular,
        AppSpacing.small,
      ),
      padding: const EdgeInsets.all(AppSpacing.large),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.group.groupMembers,
                style: context.textStyle(
                  FontSizeType.body,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$memberCount',
                style: context.textStyle(
                  FontSizeType.subheadline,
                  color: AppColors.iosGray,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.regular),
          AvatarList(
            memberList: memberList,
            width: 52,
            height: 52,
            column: (MediaQuery.sizeOf(context).width - 72) ~/ 64,
            // 点自己的头像时 people_info 会退化成空壳：那个页面靠好友关系
            // 取数，对自己既没有好友记录、也拿不到 account（user/show 白名单
            // 端点刻意不返回 account 防手机号泄露），结果只剩头像+昵称、
            // 「ID: 」空值、性别渲染成方框、零操作项。改跳自己的资料页。
            onTapAvatar: (p) => p.id.toString() == UserRepoLocal.to.currentUid
                ? context.push('/personal_info/profile')
                : context.push(
                    '/people_info/${p.id}',
                    extra: {'scene': 'group_member'},
                  ),
            onTapAdd: () =>
                context.push('/group/add_member', extra: {'groupId': groupId}),
            onTapRemove: () async {
              final res = await context.push<List<GroupMemberModel>>(
                '/group/remove_member',
                extra: {'groupId': groupId},
              );
              if (res != null) {
                for (var gm in res) {
                  ref
                      .read(groupDetailProvider.notifier)
                      .removeMember(gm.userId);
                }
                onMemberRemoved();
              }
            },
          ),
          if (memberCount > 20) ...[
            const SizedBox(height: AppSpacing.medium),
            Center(
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(
                  t.common.viewAllGroupMember,
                  style: context.textStyle(
                    FontSizeType.normal,
                    fontWeight: FontWeight.w600,
                    color: AppColors.getIosBlue(Theme.of(context).brightness),
                  ),
                ),
                onPressed: () =>
                    context.push('/group/member', extra: {'groupId': groupId}),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
