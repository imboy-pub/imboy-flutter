import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 频道角色徽标 —— 唯一来源（收敛 T01 台账 UX-ISSUE-0024 的三份实现）。
///
/// 此前 `channel_list_page`、`channel_detail_page`、`channel_header_bar`
/// 各自维护一份 角色→颜色/文案 映射；本文件是唯一权威实现，
/// 列表项、详情 AppBar、HeaderBar 的角色展示一律引用这里，
/// 禁止在新代码里再写角色色值 switch。
///
/// 视觉规格与既有 HeaderBar 版对齐：水平 10 / 垂直 4 内边距、
/// 6 圆角、角色色 12% 透明度底、tiny 加粗同色文字。
class ChannelRoleBadge extends StatelessWidget {
  const ChannelRoleBadge({super.key, required this.role, this.overridesLabel});

  /// 用户在频道中的角色。
  final ChannelUserRole role;

  /// 可选文案覆盖（特殊语境）；为空时使用 [channelRoleLabel]。
  final String? overridesLabel;

  @override
  Widget build(BuildContext context) {
    final label = overridesLabel ?? channelRoleLabel(role);
    if (label.isEmpty) return const SizedBox.shrink();

    final color = channelRoleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: context.textStyle(
          FontSizeType.tiny,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

/// 角色 → 展示色（唯一映射，勿在调用方复制此 switch）。
///
/// creator=primary / admin=iosOrange / editor=iosBlue；
/// subscriber 与 none 返回中性灰——调用方通常因 [channelRoleLabel]
/// 为空而不渲染徽标，灰值仅作兜底。
Color channelRoleColor(ChannelUserRole role) {
  switch (role) {
    case ChannelUserRole.creator:
      return AppColors.primary;
    case ChannelUserRole.admin:
      return AppColors.iosOrange;
    case ChannelUserRole.editor:
      return AppColors.iosBlue;
    case ChannelUserRole.subscriber:
    case ChannelUserRole.none:
      return AppColors.iosGray;
  }
}

/// 角色 → 当前语言文案；无角色语义（subscriber/none）返回空串，
/// [ChannelRoleBadge] 对空串渲染为零尺寸。
String channelRoleLabel(ChannelUserRole role) {
  switch (role) {
    case ChannelUserRole.creator:
      return t.channel.roleCreator;
    case ChannelUserRole.admin:
      return t.channel.roleAdmin;
    case ChannelUserRole.editor:
      return t.channel.roleEditor;
    case ChannelUserRole.subscriber:
    case ChannelUserRole.none:
      return '';
  }
}
