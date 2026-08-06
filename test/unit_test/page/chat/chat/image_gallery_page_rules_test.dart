/// Characterization tests for [resolveInitialImagePage].
///
/// slice-C-10: `chat_page.dart` L2402-2405 内联的图片预览初始页计算
/// ```dart
/// final indexOfCurrentImage = allImageUrls.indexOf(message.source);
/// final initialPage = indexOfCurrentImage >= 0 ? indexOfCurrentImage : 0;
/// ```
/// 依赖 urls 列表和当前图片 URL，零 Widget 依赖，
/// 提取后可独立单测钉死所有边界契约。
///
/// 契约（钉死）：
///   - URL 存在于列表首位 → 0
///   - URL 存在于列表中间 → 对应下标
///   - URL 存在于列表末位 → len-1
///   - URL 不在列表中 → 0（安全回退）
///   - 空列表 → 0
///   - 空字符串 URL → 0（不在列表中的特殊情形）
///   - 列表含重复 URL → 返回第一个出现的下标
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/messaging/domain/policy/image_gallery_page_rules.dart';

void main() {
  group('resolveInitialImagePage', () {
    test('URL 在列表首位 → 0', () {
      final urls = ['a.jpg', 'b.jpg', 'c.jpg'];
      expect(resolveInitialImagePage(urls, 'a.jpg'), 0);
    });

    test('URL 在列表中间 → 1', () {
      final urls = ['a.jpg', 'b.jpg', 'c.jpg'];
      expect(resolveInitialImagePage(urls, 'b.jpg'), 1);
    });

    test('URL 在列表末位 → 2', () {
      final urls = ['a.jpg', 'b.jpg', 'c.jpg'];
      expect(resolveInitialImagePage(urls, 'c.jpg'), 2);
    });

    test('URL 不在列表中 → 0（安全回退）', () {
      final urls = ['a.jpg', 'b.jpg'];
      expect(resolveInitialImagePage(urls, 'missing.jpg'), 0);
    });

    test('空列表 → 0', () {
      expect(resolveInitialImagePage([], 'a.jpg'), 0);
    });

    test('空字符串 URL → 0（不命中）', () {
      final urls = ['a.jpg', 'b.jpg'];
      expect(resolveInitialImagePage(urls, ''), 0);
    });

    test('列表含重复 URL → 返回第一个下标', () {
      final urls = ['a.jpg', 'b.jpg', 'a.jpg'];
      expect(resolveInitialImagePage(urls, 'a.jpg'), 0);
    });

    test('单元素列表 + 命中 → 0', () {
      expect(resolveInitialImagePage(['only.jpg'], 'only.jpg'), 0);
    });

    test('单元素列表 + 未命中 → 0', () {
      expect(resolveInitialImagePage(['only.jpg'], 'other.jpg'), 0);
    });
  });
}
