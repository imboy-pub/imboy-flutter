/// 群资料页"消息免打扰"开关 —— slice-7 (C6 UI) GREEN-23。
///
/// ## 设计
///
/// **受控模式**：本组件不持有状态，`value` + `onChanged` 由父层（通常读写
/// `lib/service/group_notice_config.dart` 的 `readNoticeDisabled` /
/// `setNoticeDisabled`）管理。好处：
///   1. UI 与持久化层解耦 → 纯 widget test，无 `StorageService.to` 单例依赖
///   2. 父层可自由决定更新策略（乐观更新 / 等待回调 / 错误回滚）
///
/// **iOS 原生感**（对齐 `DESIGN.md` 第 10 章）：
///   - 使用 `Switch.adaptive` → iOS 自动渲染 Cupertino 样式
///   - `ListTile` 默认高度 ≥ 48pt，满足 44pt 最小触达要求
///   - 整行可点（通过 `ListTile.onTap`），不限于 Switch 精确区域
///
/// ## 调用侧示例
///
/// ```dart
/// GroupNoticeDisabledTile(
///   label: t.group.notice_disabled, // i18n 由调用侧提供
///   value: readNoticeDisabled(gid, readBool: StorageService.to.getBool),
///   onChanged: (v) async {
///     await setNoticeDisabled(gid, v, writeBool: StorageService.to.setBool);
///     // 触发 UI 重绘（setState / ref.invalidate / ChangeNotifier.notify）
///   },
/// )
/// ```
library;

import 'package:flutter/material.dart';

class GroupNoticeDisabledTile extends StatelessWidget {
  /// 显示文案（由调用侧提供，便于 i18n / 定制）
  final String label;

  /// 当前开关值（受控）
  final bool value;

  /// 变更回调；传 `null` 表示整行禁用
  final ValueChanged<bool>? onChanged;

  const GroupNoticeDisabledTile({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    // 放进 ImBoySettingsSection（带背景色的 DecoratedBox）时，Material 版 ListTile
    // 会因找不到自身 Material 祖先而触发 _debugCheckBackgroundIsHidden 断言；
    // 按 Flutter 官方提示，给它套一层透明 Material 即可。
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        enabled: enabled,
        title: Text(label),
        trailing: Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
        ),
        // 整行可点：点击非 Switch 区域也能触发切换（满足 44pt 触达）
        onTap: enabled ? () => onChanged!(!value) : null,
      ),
    );
  }
}
