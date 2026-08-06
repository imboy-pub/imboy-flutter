import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice D: 从评论 / 发布文本中提取 `@用户名` 提及。
///
/// 设计约束：
/// - 仅做"形如 mention 的子串"识别，不解析 uid（uid 由调用方查询联系人匹配）
/// - 用户名允许包含中英文、数字、下划线，遇到空白 / 标点 / `@` 即终止
/// - 返回顺序与原文本中出现顺序一致
/// - `range` 描述的是 **包含 `@` 的整段子串** 在原文本中的位置
/// - 重复 mention 都返回（不去重，UI 层若需高亮每一处都需要 range）
void main() {
  group('extractMentions', () {
    test('单个 @用户 → 1 个 mention', () {
      const text = 'hello @alice 你好';
      final result = extractMentions(text);
      expect(result.length, 1);
      expect(result[0].name, 'alice');
      expect(result[0].start, 6);
      expect(result[0].end, 12); // '@alice' 共 6 字符
    });

    test('多个 @ 顺序保留', () {
      const text = '@bob and @carol';
      final result = extractMentions(text);
      expect(result.map((m) => m.name).toList(), ['bob', 'carol']);
    });

    test('中文用户名支持', () {
      const text = '回复 @张三 收到';
      final result = extractMentions(text);
      expect(result.length, 1);
      expect(result[0].name, '张三');
    });

    test('用户名遇到标点终止', () {
      const text = 'cc @dave, @eva.';
      final names = extractMentions(text).map((m) => m.name).toList();
      expect(names, ['dave', 'eva']);
    });

    test('@ 后立即空白或行尾不算 mention', () {
      expect(extractMentions('hi @ world').length, 0);
      expect(extractMentions('end with @').length, 0);
    });

    test('空字符串 / 纯空白 → 空列表', () {
      expect(extractMentions('').length, 0);
      expect(extractMentions('   ').length, 0);
    });

    test('range 字段精确到原文本下标（含 @）', () {
      const text = 'a @bob c';
      final m = extractMentions(text).single;
      expect(text.substring(m.start, m.end), '@bob');
    });

    test('重复 @同一人 都返回', () {
      const text = '@bob @bob @bob';
      final result = extractMentions(text);
      expect(result.length, 3);
      expect(result.every((m) => m.name == 'bob'), isTrue);
    });

    test('email 中的 @ 不被误识别（前置非空白）', () {
      // 设计选择：mention 必须前置为字符串起点 / 空白，避免邮箱误判
      const text = 'send to alice@example.com';
      expect(extractMentions(text).length, 0);
    });
  });
}
