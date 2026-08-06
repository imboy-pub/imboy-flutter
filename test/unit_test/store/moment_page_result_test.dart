import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/api/moment_api.dart';

/// `MomentPageResult.fromPayload` 的 hasMore 判据。
///
/// 回归的真 bug：原来三处（feed / user posts / comments）都按「cursor 非空」
/// 推 hasMore，而服务端对最后一页也照样回一个 cursor —— 只有 1 条评论时
/// 「加载更多」照样显示，底部永远转圈。判据改为「本页满一页」。
void main() {
  Map<String, dynamic> payload(int count, {String? cursor = 'c1'}) => {
    'list': List.generate(count, (i) => {'id': 'id$i'}),
    if (cursor != null) 'cursor': cursor,
  };

  group('MomentPageResult.fromPayload hasMore', () {
    test('满一页 + cursor 非空 → true', () {
      final page = MomentPageResult.fromPayload(payload(20), limit: 20);
      expect(page.hasMore, isTrue);
      expect(page.list, hasLength(20));
      expect(page.nextCursor, 'c1');
    });

    test('不满一页但 cursor 非空 → false（服务端末页照样回 cursor）', () {
      final page = MomentPageResult.fromPayload(payload(1), limit: 20);
      expect(page.hasMore, isFalse);
      // cursor 仍原样透出，不改对外契约
      expect(page.nextCursor, 'c1');
    });

    test('空列表 + cursor 非空 → false', () {
      expect(
        MomentPageResult.fromPayload(payload(0), limit: 20).hasMore,
        isFalse,
      );
    });

    test('满一页但 cursor 缺失 → false（无游标翻不了页）', () {
      final page = MomentPageResult.fromPayload(
        payload(20, cursor: null),
        limit: 20,
      );
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });

    test('满一页但 cursor 为空串 → false', () {
      final page = MomentPageResult.fromPayload(
        payload(20, cursor: ''),
        limit: 20,
      );
      expect(page.hasMore, isFalse);
    });

    test('超过一页（后端多返）→ true', () {
      expect(
        MomentPageResult.fromPayload(payload(21), limit: 20).hasMore,
        isTrue,
      );
    });

    test('limit <= 0 → false，不因 `length >= 0` 恒真而误判有下一页', () {
      expect(
        MomentPageResult.fromPayload(payload(0), limit: 0).hasMore,
        isFalse,
      );
    });
  });

  group('MomentPageResult.fromPayload 解析防御', () {
    test('list 字段缺失 → 空列表 + hasMore false', () {
      final page = MomentPageResult.fromPayload({'cursor': 'c1'}, limit: 20);
      expect(page.list, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('list 非 List → 空列表', () {
      final page = MomentPageResult.fromPayload({
        'list': 'oops',
        'cursor': 'c1',
      }, limit: 20);
      expect(page.list, isEmpty);
    });

    test('list 内非 Map 条目被丢弃，只按有效条目数判满页', () {
      final page = MomentPageResult.fromPayload({
        'list': [
          {'id': 'a'},
          'junk',
          {'id': 'b'},
        ],
        'cursor': 'c1',
      }, limit: 3);
      expect(page.list, hasLength(2));
      expect(page.hasMore, isFalse);
    });

    test('empty 常量：空列表 / 无 cursor / 无下一页', () {
      expect(MomentPageResult.empty.list, isEmpty);
      expect(MomentPageResult.empty.nextCursor, isNull);
      expect(MomentPageResult.empty.hasMore, isFalse);
    });
  });
}
