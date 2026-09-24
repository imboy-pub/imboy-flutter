import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'group_app_grid.dart';
import '../group_detail_service.dart';

/// 构建群应用九宫格入口。每项跳转对应协作子页面路由。
///
/// ENT-APP-02 等价拆分：自 group_detail_page.dart `_buildAppItems` 机械
/// 搬运为顶层函数。二维码项异步 find 后的 `mounted` 检查（原引用页面
/// State）经 [isMounted] 回调注入，行为逐行等价。
List<GroupAppItem> buildGroupAppItems(
  BuildContext context,
  String groupId,
  GroupModel? group, {
  bool Function()? isMounted,
}) {
  final gid = groupId;
  return [
    GroupAppItem(
      icon: CupertinoIcons.speaker_2_fill,
      label: t.common.groupAnnouncement,
      color: AppColors.iosOrange,
      onTap: () => context.push('/group/announcement', extra: {'groupId': gid}),
    ),
    GroupAppItem(
      icon: CupertinoIcons.folder_fill,
      label: t.chat.groupFile,
      color: AppColors.iosBlue,
      onTap: () => context.push('/group/$gid/file'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.photo_fill,
      label: t.group.groupAlbum,
      color: AppColors.iosGreen,
      onTap: () => context.push('/group/$gid/album'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.chart_bar_square_fill,
      label: t.groupVote.title,
      color: AppColors.iosPurple,
      onTap: () => context.push('/group/$gid/vote'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.calendar,
      label: t.groupSchedule.title,
      color: AppColors.iosRed,
      onTap: () => context.push('/group/$gid/schedule'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.checkmark_seal_fill,
      label: t.groupTask.title,
      color: AppColors.iosTeal,
      onTap: () => context.push('/group/$gid/task'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.tag_fill,
      label: t.groupTag.title,
      color: AppColors.iosSkyBlue,
      onTap: () => context.push('/group/$gid/tag'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.folder_open,
      label: t.groupCategory.title,
      color: AppColors.iosYellow,
      onTap: () => context.push('/group/category'),
    ),
    GroupAppItem(
      icon: CupertinoIcons.qrcode,
      label: t.account.groupQrcode,
      color: AppColors.iosGray,
      onTap: () async {
        final g = group ?? await GroupDetailService().find(gid);
        // `isMounted()`（页面 State.mounted）通过时 context.mounted 恒真，
        // 此处显式声明以通过 use_build_context_synchronously（行为等价）。
        if (g != null &&
            (isMounted == null || isMounted()) &&
            context.mounted) {
          context.push('/qrcode/group', extra: {'group': g});
        }
      },
    ),
  ];
}
