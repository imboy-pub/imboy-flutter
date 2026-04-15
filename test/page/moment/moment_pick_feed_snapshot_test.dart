import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice E: feed 离线兜底纯函数。
///
/// 调用方契约：
/// - 远程拉取成功 → 传 `remote = page.list`（即使空列表也算成功）
/// - 远程拉取失败 / 抛异常 → 传 `remote = null`
/// - `cached` 始终非 null（empty 表示真没缓存）
///
/// 返回值告诉 UI：
/// - 用哪份数据渲染
/// - 是否打"网络异常 / 离线"标记（`isStale`）
void main() {
  group('pickFeedSnapshot', () {
    test('远程成功 → 用 remote，isStale=false', () {
      final remote = [
        {'id': 'm1'},
      ];
      final cached = [
        {'id': 'old'},
      ];
      final snapshot = pickFeedSnapshot(remote: remote, cached: cached);
      expect(snapshot.items, remote);
      expect(snapshot.isStale, isFalse);
    });

    test('远程返回空列表 → 用空 remote，isStale=false（用户清空了所有动态）', () {
      final cached = [
        {'id': 'old'},
      ];
      final snapshot = pickFeedSnapshot(remote: const [], cached: cached);
      expect(snapshot.items, isEmpty);
      expect(snapshot.isStale, isFalse);
    });

    test('远程失败 + 有缓存 → 用 cached，isStale=true', () {
      final cached = [
        {'id': 'old1'},
        {'id': 'old2'},
      ];
      final snapshot = pickFeedSnapshot(remote: null, cached: cached);
      expect(snapshot.items, cached);
      expect(snapshot.isStale, isTrue);
    });

    test('远程失败 + 无缓存 → 空列表，isStale=true（让 UI 显示离线空态）', () {
      final snapshot = pickFeedSnapshot(remote: null, cached: const []);
      expect(snapshot.items, isEmpty);
      expect(snapshot.isStale, isTrue);
    });

    test('返回的 items 是新 list（避免外部意外修改 cached）', () {
      final cached = [
        {'id': 'a'},
      ];
      final snapshot = pickFeedSnapshot(remote: null, cached: cached);
      expect(identical(snapshot.items, cached), isFalse,
          reason: '应返回 cached 的浅拷贝');
    });
  });
}
