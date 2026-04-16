/// 群成员禁言时长选项（slice-10a）。
///
/// 纯 Dart，无外部依赖。UI 层通过 [labelKey] 映射 i18n 字符串。
library;

/// 单个禁言时长选项的数据载体。
///
/// [seconds]  — 禁言秒数（必须 > 0）。
/// [labelKey] — 对应 i18n 键名，供 UI 层通过 `t.<labelKey>` 获取本地化文案。
final class MuteDurationOption {
  final int seconds;
  final String labelKey;

  const MuteDurationOption({required this.seconds, required this.labelKey});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MuteDurationOption &&
          other.seconds == seconds &&
          other.labelKey == labelKey;

  @override
  int get hashCode => Object.hash(seconds, labelKey);

  @override
  String toString() =>
      'MuteDurationOption(seconds: $seconds, labelKey: $labelKey)';
}

/// 标准禁言时长列表（按秒升序）。
///
/// 对应后端 `group_member_logic:mute/4` 接受的 duration 参数（秒）。
/// UI 层可直接渲染此列表，通过 [MuteDurationOption.labelKey] 获取本地化文案。
/// labelKey 命名对齐既有 `muteDuration*` 约定（见 assets/i18n/*.i18n.yaml）。
/// 3600 / 86400 / 604800 复用已有键；其余为 slice-10a 新增。
const List<MuteDurationOption> muteDurationOptions = [
  MuteDurationOption(seconds: 300,     labelKey: 'muteDuration5min'),
  MuteDurationOption(seconds: 600,     labelKey: 'muteDuration10min'),
  MuteDurationOption(seconds: 1800,    labelKey: 'muteDuration30min'),
  MuteDurationOption(seconds: 3600,    labelKey: 'muteDuration1hour'),   // 既有键
  MuteDurationOption(seconds: 86400,   labelKey: 'muteDuration1day'),    // 既有键
  MuteDurationOption(seconds: 604800,  labelKey: 'muteDuration7days'),   // 既有键
  MuteDurationOption(seconds: 2592000, labelKey: 'muteDuration30days'),
];
