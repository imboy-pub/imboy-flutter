/// 评论 @ 传递契约测试 —— 钉死从评论文本提取 mentions 名字列表的行为。
///
/// 背景：
///   `_addComment` 在发送评论前调用 `extractMentions(content)`，
///   将 `.map((m) => m.name).toList()` 结果作为 `mentions` 字段
///   传入 `MomentApi.addComment`，再发往后端。
///
/// 本测试钉死：
///   1. 带 @mention 的评论 → 提取出名字列表（非空）
///   2. 无 @mention 的评论 → 空列表（不传 mentions 字段）
///   3. 多个 @mention → 保序去重
///   4. 只含 @mention 的评论 → 仍提取正确
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// 从评论文本中提取 mention 名字列表 —— 对应 `_addComment` 内联逻辑。
List<String> extractMentionNames(String text) =>
    extractMentions(text).map((m) => m.name).toList();

void main() {
  group('extractMentionNames（评论 body mentions 字段准备）', () {
    // ─────────────────────────────────────────────────────────
    // 基础行为
    // ─────────────────────────────────────────────────────────
    test('带单个 @mention → 返回 1 个名字', () {
      final names = extractMentionNames('好的 @alice 没问题');
      expect(names, ['alice']);
    });

    test('多个 @mention 保序返回', () {
      final names = extractMentionNames('@bob 和 @carol 都在');
      expect(names, ['bob', 'carol']);
    });

    test('中文昵称正常提取', () {
      final names = extractMentionNames('回复 @张三 收到了');
      expect(names, ['张三']);
    });

    // ─────────────────────────────────────────────────────────
    // 空/无 mention → 空列表（不应附加 mentions 字段）
    // ─────────────────────────────────────────────────────────
    test('无 @mention 的评论 → 空列表', () {
      final names = extractMentionNames('普通评论，没有at任何人');
      expect(names, isEmpty);
    });

    test('空字符串 → 空列表', () {
      expect(extractMentionNames(''), isEmpty);
    });

    // ─────────────────────────────────────────────────────────
    // 边界
    // ─────────────────────────────────────────────────────────
    test('只含 @mention → 仍提取', () {
      final names = extractMentionNames('@dave');
      expect(names, ['dave']);
    });

    test('邮箱格式不被误识别', () {
      final names = extractMentionNames('联系 alice@example.com');
      expect(names, isEmpty);
    });
  });
}
