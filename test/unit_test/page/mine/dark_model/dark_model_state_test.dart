import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/mine/dark_model/dark_model_page.dart';

/// DarkModelState.copyWith 纯逻辑单测
///
/// State 类为纯内存对象，copyWith 不触发 themeProvider 单例链
/// （仅 Notifier.build() 才 watch themeProvider），可直接 new 测试。
void main() {
  group('DarkModelState defaults', () {
    test('默认 switchValue=false, selectIndex=2', () {
      const s = DarkModelState();
      expect(s.switchValue, false);
      expect(s.selectIndex, 2);
    });
  });

  group('DarkModelState.copyWith', () {
    test('更新 switchValue 保留 selectIndex', () {
      const s = DarkModelState(selectIndex: 3);
      final next = s.copyWith(switchValue: true);
      expect(next.switchValue, true);
      expect(next.selectIndex, 3);
    });

    test('更新 selectIndex 保留 switchValue', () {
      const s = DarkModelState(switchValue: true);
      final next = s.copyWith(selectIndex: 2);
      expect(next.selectIndex, 2);
      expect(next.switchValue, true);
    });

    test('未传参返回等价新副本（不可变）', () {
      const s = DarkModelState(switchValue: true, selectIndex: 3);
      final copy = s.copyWith();
      expect(copy.switchValue, true);
      expect(copy.selectIndex, 3);
      expect(identical(copy, s), false);
    });
  });
}
