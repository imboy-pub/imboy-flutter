import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_interactions.dart';

/// Slice G: 朋友圈发布媒体校验。
///
/// 微信对齐规则：
/// - 最多 9 张图片
/// - 最多 1 个视频
/// - 图片 / 视频互斥（不能混排）
/// - 空选择是合法的（纯文字动态）
///
/// 校验返回结构化结果而非抛异常，UI 层据此决定 toast 文案 + 是否拦截发布。
void main() {
  group('validateMediaSelection', () {
    test('空列表 → ok（纯文字动态）', () {
      final r = validateMediaSelection(const []);
      expect(r.ok, isTrue);
      expect(r.error, momentMediaErrorNone);
    });

    test('1-9 张图片 → ok', () {
      for (var n = 1; n <= 9; n++) {
        final items = List.generate(n, (_) => {'type': 'image'});
        final r = validateMediaSelection(items);
        expect(r.ok, isTrue, reason: '$n images should be ok');
      }
    });

    test('10 张图片 → tooManyImages', () {
      final items = List.generate(10, (_) => {'type': 'image'});
      final r = validateMediaSelection(items);
      expect(r.ok, isFalse);
      expect(r.error, momentMediaErrorTooManyImages);
    });

    test('1 个视频 → ok', () {
      final r = validateMediaSelection(const [
        {'type': 'video'},
      ]);
      expect(r.ok, isTrue);
    });

    test('2 个视频 → tooManyVideos', () {
      final r = validateMediaSelection(const [
        {'type': 'video'},
        {'type': 'video'},
      ]);
      expect(r.ok, isFalse);
      expect(r.error, momentMediaErrorTooManyVideos);
    });

    test('图片 + 视频混排 → mixedImageAndVideo', () {
      final r = validateMediaSelection(const [
        {'type': 'image'},
        {'type': 'video'},
      ]);
      expect(r.ok, isFalse);
      expect(r.error, momentMediaErrorMixed);
    });

    test('图片+视频混排即使在限额内也判 mixed（优先级高于 tooMany）', () {
      // 1 image + 1 video — neither超限，但仍非法
      final r = validateMediaSelection(const [
        {'type': 'video'},
        {'type': 'image'},
      ]);
      expect(r.error, momentMediaErrorMixed);
    });

    test('未知 type 视为 image（保守，按上限 9 校验）', () {
      // 朋友圈历史载荷可能缺 type，按图片处理而非整盘拒绝
      final items = List.generate(9, (_) => <String, dynamic>{});
      expect(validateMediaSelection(items).ok, isTrue);
      expect(
        validateMediaSelection(List.generate(10, (_) => <String, dynamic>{})).error,
        momentMediaErrorTooManyImages,
      );
    });

    test('错误码常量稳定', () {
      // 与 i18n key / 上层 switch 强绑定，禁止随意重命名
      expect(momentMediaErrorNone, 'none');
      expect(momentMediaErrorTooManyImages, 'too_many_images');
      expect(momentMediaErrorTooManyVideos, 'too_many_videos');
      expect(momentMediaErrorMixed, 'mixed_image_and_video');
    });
  });
}
