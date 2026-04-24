/// 禁言剩余时间徽章 —— F2 GREEN。
///
/// 包裹 `muteRemainingLabel`（slice-2 纯函数），将其纯文本输出渲染为一个
/// 破坏性语义（error color）的小圆角 badge。
///
/// ## 设计
///
/// **纯受控**：`muteUntilMs` + `nowMs` 由父层提供（通常父层持有成员列表并
/// 在列表构建时调用 `DateTime.now().millisecondsSinceEpoch`）。本组件不订阅
/// 时钟 —— 禁言徽章逐秒 tick 意义不大；列表下拉刷新或返回重入即可重算。
///
/// **空值即不渲染**：`muteRemainingLabel` 返回 `''` 时输出
/// `SizedBox.shrink()`，在 `Row` 中不占位。
library;

import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_member/group_member_mute_rules.dart';
import 'package:imboy/theme/default/app_colors.dart';

class MuteRemainingBadge extends StatelessWidget {
  /// 解禁时间（毫秒 epoch）；`null` 或 <= `nowMs` 视为未禁言。
  final int? muteUntilMs;

  /// 参考时间戳；由父层注入，测试可传固定值。
  final int nowMs;

  const MuteRemainingBadge({
    super.key,
    required this.muteUntilMs,
    required this.nowMs,
  });

  @override
  Widget build(BuildContext context) {
    final label = muteRemainingLabel(muteUntilMs: muteUntilMs, nowMs: nowMs);
    if (label.isEmpty) return const SizedBox.shrink();

    final color = AppColors.getIosRed(Theme.of(context).brightness);
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        t.mutedFor(label: label),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
