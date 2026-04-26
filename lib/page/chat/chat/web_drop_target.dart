/// Phase 2.3 — Web 拖拽上传 widget 骨架（接缝设计）
///
/// 包裹 child + 接受外部 isDragging 状态 → 拖拽时叠加 overlay 提示。
/// DOM dragenter/dragover/drop 监听不在本 widget 内（避免引入 package:web 依赖
/// 影响非 Web 平台编译）— 由调用方在 Web 入口处用 conditional import 注入。
///
/// 设计原则（与 1.1.d WebWelcomePanel / 2.1 ChatPanel 一致）：
/// - **无业务依赖**：onDrop 回调由调用方实现
/// - **无 i18n 依赖**：dragHint 通过 props 注入
/// - **响应主题**：用 ColorScheme 取色
/// - **接缝设计**：DOM 事件监听 / File 类型转换留给调用方（Web stub vs mobile no-op）
library;

import 'package:flutter/material.dart';

/// Web 拖拽上传 widget
class WebDropTarget extends StatelessWidget {
  /// 内部内容（消息列表 / ChatPanel body 等）
  final Widget child;

  /// 是否当前有拖拽进入（由调用方控制，触发 overlay 显示）
  final bool isDragging;

  /// 拖拽提示文字（如 "释放即可上传" / "Drop to upload"）
  final String dragHint;

  /// 拖拽图标（默认 cloud_upload）
  final IconData dragIcon;

  const WebDropTarget({
    super.key,
    required this.child,
    required this.isDragging,
    required this.dragHint,
    this.dragIcon = Icons.cloud_upload_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (isDragging) _DropOverlay(hint: dragHint, icon: dragIcon),
      ],
    );
  }
}

class _DropOverlay extends StatelessWidget {
  final String hint;
  final IconData icon;

  const _DropOverlay({required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      color: colorScheme.primary.withAlpha(51), // ≈ 0.20 alpha
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                hint,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
