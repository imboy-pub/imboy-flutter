import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// AI / 官方账号身份徽章（透明 AI 路线的客户端披露载体）。
///
/// account_type 语义（服务端只读投影，客户端无写入路径）：
/// - 0 真人：不渲染（返回 [SizedBox.shrink]）
/// - 1 AI 助手：「AI」pill，teal（tertiary）tint 底 + 饱和前景 + sparkles 图标
/// - 2 官方机器人：「官方」pill，品牌蓝 tint 底 + checkmark_seal 图标
/// - 其他未知值：兜底不渲染
///
/// 身份不单靠颜色传达：图标形状 + 文字双通道（WCAG 1.4.1），
/// 并带 Semantics 标签供屏幕阅读器朗读。
class BotBadge extends StatelessWidget {
  const BotBadge({super.key, required this.accountType, this.compact = false});

  /// 见类注释的 account_type 语义。
  final int accountType;

  /// 紧凑模式：仅图标不带文字（导航栏标题等窄空间用），
  /// Semantics 标签仍完整朗读身份。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return switch (accountType) {
      1 => _pill(
        context,
        label: t.agent.badgeAi,
        a11yLabel: t.agent.badgeAiA11y,
        color: AppColors.tertiary,
        icon: CupertinoIcons.sparkles,
      ),
      2 => _pill(
        context,
        label: t.agent.badgeOfficial,
        a11yLabel: t.agent.badgeOfficialA11y,
        color: AppColors.primary,
        icon: CupertinoIcons.checkmark_seal_fill,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required String a11yLabel,
    required Color color,
    required IconData icon,
  }) {
    return Semantics(
      label: a11yLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.small,
          vertical: AppSpacing.tiny,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.tag,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标尺寸非 token 管辖，12 对齐 caption2 字号视觉
            Icon(icon, size: 12, color: color),
            if (!compact) ...[
              AppSpacing.horizontalTiny,
              Text(
                label,
                style: context.textStyle(
                  FontSizeType.caption2,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
