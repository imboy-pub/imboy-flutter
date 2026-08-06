import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// `removeCommentById` 契约（与 `removeMomentById` 同构）：
/// - 返回不可增长的新 list，不 mutate 输入
/// - 匹配 `id` 字段；空 id 视为无效 → 原样返回拷贝（防御，避免误删全部）
/// - 用 `parseModelString(item['id'])` 统一格式，兼容后端返回 int/String
void main() {
  Map<String, dynamic> c(dynamic id, {String content = ''}) =>
      <String, dynamic>{'id': id, 'content': content};

  group('removeCommentById', () {
    test('removes the matching comment and preserves others', () {
      final input = [c('1'), c('2'), c('3')];
      final result = removeCommentById(input, '2');
      expect(result.map((e) => e['id']), ['1', '3']);
    });

    test('returns identical content when id not found', () {
      final input = [c('1'), c('2')];
      final result = removeCommentById(input, 'nope');
      expect(result.map((e) => e['id']), ['1', '2']);
    });

    test('empty id returns a defensive copy (no deletion)', () {
      final input = [c('1'), c('2')];
      final result = removeCommentById(input, '');
      expect(result.map((e) => e['id']), ['1', '2']);
    });

    test('does not mutate input list', () {
      final input = [c('1'), c('2')];
      removeCommentById(input, '1');
      expect(input.map((e) => e['id']), ['1', '2']);
    });

    test('returns a non-growable list', () {
      final result = removeCommentById([c('1')], 'x');
      expect(() => result.add(c('2')), throwsUnsupportedError);
    });

    test('handles numeric id from backend (int vs string parity)', () {
      final input = [c(1), c(2)];
      final result = removeCommentById(input, '1');
      expect(result.map((e) => e['id']), [2]);
    });
  });
}
