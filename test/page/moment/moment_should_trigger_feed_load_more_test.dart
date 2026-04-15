import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// `shouldTriggerFeedLoadMore` 契约：
/// - 三段 guard 合一：`isLoadingMore` / `!hasMore` / 距底距离 < threshold → false
/// - 触发条件：`pixels >= maxExtent - threshold`（含边界，>= 而非 >），
///   与原始 `_onScroll` 行为完全一致；改成 > 会让边界刚好触底的快速滚动错过加载
/// - threshold 默认 320 像素（提前 320px 预拉，UI 顺滑）
/// - 不依赖 ScrollController / Flutter，纯数学决策，便于端到端边界测试
void main() {
  group('shouldTriggerFeedLoadMore', () {
    test('returns false while a load is already in flight', () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 10000,
          maxExtent: 10000,
          isLoadingMore: true,
          hasMore: true,
        ),
        isFalse,
      );
    });

    test('returns false when there is no more data', () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 10000,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: false,
        ),
        isFalse,
      );
    });

    test('returns false when scroll is far above the threshold', () {
      // 10000 - 320 = 9680；当前 5000，远未到预拉区
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 5000,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
        ),
        isFalse,
      );
    });

    test('returns true exactly at the prefetch boundary (pixels = max - 320)',
        () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 9680,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
        ),
        isTrue,
      );
    });

    test('returns true when scrolled past the boundary', () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 9700,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
        ),
        isTrue,
      );
    });

    test('returns true on overscroll (pixels > maxExtent)', () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 10500,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
        ),
        isTrue,
      );
    });

    test('custom threshold honored (threshold = 0 means trigger only at bottom)',
        () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 9999,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
          threshold: 0,
        ),
        isFalse,
      );
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 10000,
          maxExtent: 10000,
          isLoadingMore: false,
          hasMore: true,
          threshold: 0,
        ),
        isTrue,
      );
    });

    test('small list (maxExtent < threshold) still triggers when at bottom',
        () {
      // maxExtent=100, threshold=320 → max-threshold=-220；pixels>=-220 总是真
      // 这是有意行为：列表本就不足一屏时，任何滚动到底都应允许加载下一页
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 50,
          maxExtent: 100,
          isLoadingMore: false,
          hasMore: true,
        ),
        isTrue,
      );
    });

    test('zero pixels with empty list does not crash (degenerate case)', () {
      expect(
        shouldTriggerFeedLoadMore(
          pixels: 0,
          maxExtent: 0,
          isLoadingMore: false,
          hasMore: true,
        ),
        isTrue, // 0 >= 0 - 320 → true；调用方靠 hasMore=false 拦截
      );
    });
  });
}
