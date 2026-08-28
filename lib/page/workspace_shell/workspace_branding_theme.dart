/// T12 (WP5) — Workspace Branding 主题作用域（仅 Workspace 视图生效）
///
/// 作用域声明（计划 T12）：进入 workspace_shell 时按当前工作区
/// `branding.primaryColor` 覆盖主题主色；离开（切回 Chat 壳 / 退出工作区
/// 子树）即还原——作用域只包在本壳内，天然随子树销毁而还原，不滑向
/// 多租户（无域名路由、无数据隔离）。
///
/// 颜色规则（硬性约束）：
/// - 颜色一律经 AppColors 体系消费；本层只做「branding 覆盖色」的解析
///   与注入（`ColorScheme.primary`），不产生新的硬编码色板
/// - primaryColor 解析失败 / 为空 → 回落 `ColorScheme.primary` 现值
///   （即主题默认，不覆盖）
///
/// 测试锚点：两个不同 branding 的 workspace 切换各自生效（widget 断言）。
library;

import 'package:flutter/material.dart';

import 'package:imboy/store/model/workspace_model.dart';

/// 解析 branding.primaryColor 为 [Color]。
///
/// 接受 `#RRGGBB` / `#AARRGGBB` / `RRGGBB` / `AARRGGBB`；空串 / 非法值 /
/// 超长值返回 null（调用方回落默认主题色，绝不吞成白色黑屏）。
Color? parseBrandingPrimaryColor(String raw) {
  var s = raw.trim();
  if (s.isEmpty || s.length > 9) return null;
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length != 6 && s.length != 8) return null;
  final argb = s.length == 8 ? s : 'FF$s';
  final value = int.tryParse(argb, radix: 16);
  if (value == null) return null;
  return Color(value);
}

/// 按 branding 构建作用域内 ColorScheme。
///
/// 解析失败 / 未配置 → 原样返回 base（主题默认主色，不覆盖）。
/// 仅覆盖 primary 一处：Material 3 的 primaryContainer / onPrimary 等
/// 派生色继续走主题默认，避免自造色板（AppColors 体系外零新增颜色）。
ColorScheme buildWorkspaceColorScheme(ColorScheme base, String primaryColor) {
  final parsed = parseBrandingPrimaryColor(primaryColor);
  if (parsed == null) return base;
  return base.copyWith(primary: parsed);
}

/// Workspace Branding 主题作用域 widget。
///
/// 包裹 workspace_shell 的全部内容：子树内 `Theme.of(context).colorScheme`
/// 的 primary 为 branding.primaryColor；子树外（Chat 壳 / 其他页面）不受
/// 影响。branding 变化（切换工作区 / Owner 改色）时随参数重建。
class WorkspaceBrandingScope extends StatelessWidget {
  final WorkspaceBranding branding;
  final Widget child;

  const WorkspaceBrandingScope({
    super.key,
    required this.branding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = buildWorkspaceColorScheme(
      theme.colorScheme,
      branding.primaryColor,
    );
    if (identical(colorScheme, theme.colorScheme)) {
      return child;
    }
    return Theme(
      data: theme.copyWith(colorScheme: colorScheme),
      child: child,
    );
  }
}
