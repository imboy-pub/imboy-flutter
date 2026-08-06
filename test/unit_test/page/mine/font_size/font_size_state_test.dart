import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/theme/default/font_types.dart';

/// FontSizeState 纯内存单测（直接 new，不依赖单例/Provider）。
void main() {
  group('FontSizeState copyWith', () {
    const base = FontSizeState(
      currentOption: FontSizeOption.normal,
      previewOption: FontSizeOption.normal,
      sliderValue: 1.0,
    );

    test('copyWith with no args keeps all fields unchanged', () {
      final next = base.copyWith();
      expect(next.currentOption, FontSizeOption.normal);
      expect(next.previewOption, FontSizeOption.normal);
      expect(next.sliderValue, 1.0);
    });

    test('copyWith updates only previewOption and sliderValue', () {
      final next = base.copyWith(
        previewOption: FontSizeOption.large,
        sliderValue: 3.0,
      );
      expect(next.previewOption, FontSizeOption.large);
      expect(next.sliderValue, 3.0);
      // 未传入的字段保持不变
      expect(next.currentOption, FontSizeOption.normal);
    });

    test('copyWith updates currentOption independently', () {
      final next = base.copyWith(currentOption: FontSizeOption.huge);
      expect(next.currentOption, FontSizeOption.huge);
      expect(next.previewOption, FontSizeOption.normal);
      expect(next.sliderValue, 1.0);
    });
  });
}
