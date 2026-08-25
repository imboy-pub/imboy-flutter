/// 群资料页"消息免打扰"开关 —— Cupertino 风格。
///
/// **受控模式**：本组件不持有状态，`value` + `onChanged` 由父层管理。
///
/// 使用 `CupertinoListTile.notched()` + `CupertinoSwitch` 替代原 Material
/// `ListTile` + `Switch.adaptive`，消除群模块最后一个 Material 组件。
library;

import 'package:flutter/cupertino.dart';
import 'package:imboy/theme/default/font_types.dart';

class GroupNoticeDisabledTile extends StatelessWidget {
  final String label;
  final bool value;
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
    return CupertinoListTile.notched(
      title: Text(label, style: context.textStyle(FontSizeType.body)),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      // 整行可点：点击非 Switch 区域也能触发切换（满足 44pt 触达）
      onTap: enabled ? () => onChanged!(!value) : null,
    );
  }
}
