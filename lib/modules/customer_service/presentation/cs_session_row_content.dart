/// 会话行共用信息布局（T19/P3-04）— imboy-enterprise-uiux-v1
///
/// 纯展示组件：待接队列（cs_queue_view）与处理中/已关闭列表
///（cs_session_list_view）共用的信息顺序 —— 掩码名 → 摘要 → 来源。
///
/// 契约：**无 API/provider/权限依赖**。掩码名、摘要、来源与尾部动作区
/// 均为调用方注入的显示输入/内容 widget；页面保留各自的
/// _fetchPage/_claim/_open 与全部作用域。
library;

import 'package:flutter/material.dart';

import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

class CsSessionRowContent extends StatelessWidget {
  /// 客户掩码名（调用方经 csMaskContactName 产物）。
  final String maskedName;

  /// 摘要区（调用方组装的 csQueuePreviewText 产物）。
  final Widget preview;

  /// 来源区 widget（调用方决定展示名或整体隐藏）。
  final Widget source;

  /// 尾部动作区（队列=接单按钮；会话列表=chevron）。
  final Widget? trailing;

  const CsSessionRowContent({
    super.key,
    required this.maskedName,
    required this.preview,
    required this.source,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.regular,
        vertical: AppSpacing.medium,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maskedName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.verticalTiny,
                preview,
                source,
              ],
            ),
          ),
          if (trailing != null) ...[AppSpacing.horizontalSmall, trailing!],
        ],
      ),
    );
  }
}
