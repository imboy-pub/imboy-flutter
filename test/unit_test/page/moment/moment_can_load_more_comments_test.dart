import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice B: 把 `_loadMoreComments` 顶部分散的三段 guard
///   - `isLoading`
///   - `!hasMore`
///   - `cursor == null || cursor.isEmpty`
/// 合并成一个纯谓词，避免 feed/detail 两处复制粘贴漂移。
void main() {
  group('canLoadMoreComments', () {
    test('正常可加载：未在加载、还有更多、cursor 非空 → true', () {
      expect(
        canLoadMoreComments(isLoading: false, hasMore: true, cursor: 'c1'),
        isTrue,
      );
    });

    test('正在加载 → false（即使 hasMore 与 cursor 都 OK）', () {
      expect(
        canLoadMoreComments(isLoading: true, hasMore: true, cursor: 'c1'),
        isFalse,
      );
    });

    test('hasMore=false → false', () {
      expect(
        canLoadMoreComments(isLoading: false, hasMore: false, cursor: 'c1'),
        isFalse,
      );
    });

    test('cursor=null → false', () {
      expect(
        canLoadMoreComments(isLoading: false, hasMore: true, cursor: null),
        isFalse,
      );
    });

    test('cursor 空字符串 → false', () {
      expect(
        canLoadMoreComments(isLoading: false, hasMore: true, cursor: ''),
        isFalse,
      );
    });

    test('cursor 纯空白 → false（防御后端脏数据）', () {
      expect(
        canLoadMoreComments(isLoading: false, hasMore: true, cursor: '   '),
        isFalse,
      );
    });
  });
}
