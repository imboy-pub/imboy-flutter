/// @提及候选列表排序（C2 Layer A）
///
/// 纯函数：按每个成员的发言次数降序排列。
///
/// 约定（见对应测试）：
///   - 稳定排序：频次相等时保持输入相对顺序
///   - countMap 缺失的成员视为 0
///   - countMap 中不在 members 列表里的条目一律忽略
///   - 输入列表不会被就地修改
///   - `isAllMention == true` 的候选（@所有人）永远置顶，不参与频率比较
library;

import 'package:imboy/component/chat/mention_model.dart';

class MentionRanking {
  MentionRanking._();

  /// 对 [members] 按 [sendCount] 降序重排，返回新列表。
  ///
  /// @所有人 候选（若存在）始终排在结果第一位。
  static List<MentionCandidate> sortByFrequency(
    List<MentionCandidate> members,
    Map<String, int> sendCount,
  ) {
    if (members.isEmpty) return const [];

    // 分离 @所有人 候选；其余参与频率排序。
    final allMentions = <MentionCandidate>[];
    final ranked = <MentionCandidate>[];
    for (final m in members) {
      if (m.isAllMention) {
        allMentions.add(m);
      } else {
        ranked.add(m);
      }
    }

    // 稳定排序：Dart List.sort 是 stable（VM + JS 实现均保证）。
    // 频率相等时 compare 返回 0，保留原顺序。
    ranked.sort((a, b) {
      final ca = sendCount[a.userId] ?? 0;
      final cb = sendCount[b.userId] ?? 0;
      return cb.compareTo(ca); // desc
    });

    return [...allMentions, ...ranked];
  }
}
