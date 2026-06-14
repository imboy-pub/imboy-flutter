/// Phase 1.1.d — Web Shell 默认欢迎屏（无业务依赖纯 widget）
///
/// 当 [WebShellState.selectedItem] 为 null 时在右栏渲染。
///
/// 设计原则：
/// - **无 i18n 依赖**：title/subtitle 通过参数注入，由调用方（[WebShellPage] 后续切片）
///   注入 slang 文案，本 widget 保持文案无关
/// - **无业务依赖**：纯 Material widget，不引入 Riverpod / Repo / Provider
/// - **响应主题**：用 [ColorScheme] / [TextTheme] 取色，亮暗模式自动适配
/// - **最大宽度约束**：长文案在大屏不会撑满，居中阅读体验更佳
library;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Web Shell 默认欢迎屏
class WebWelcomePanel extends StatelessWidget {
  /// 主标题（必填，由调用方传入 i18n 文案）
  final String title;

  /// 副标题（可选，引导用户行动的辅助文案）
  final String? subtitle;

  /// 中央展示图标（默认聊天气泡）
  final IconData icon;

  /// 内容最大宽度约束（避免大屏文案撑满，提升阅读舒适度）
  final double maxWidth;

  const WebWelcomePanel({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.chat_bubble_outline,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      color: colorScheme.surface,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 96,
              // 0.6 * 255 ≈ 153，避免使用已弃用的 withOpacity（项目惯用 withAlpha）
              color: colorScheme.primary.withAlpha(153),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
