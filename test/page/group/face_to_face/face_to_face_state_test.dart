import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';

/// FaceToFaceState 纯不可变状态类契约测试（TypeB）。
///
/// 仅覆盖纯内存 copyWith 行为，不触及 Notifier 的定位/GroupApi 网络方法。
void main() {
  group('FaceToFaceState — copyWith', () {
    final controller = NumericKeypadController('');

    FaceToFaceState base() => FaceToFaceState(
      textEditingController: controller,
      errorInfo: 'e0',
      resultData: 'r0',
      longitude: '113.0',
      latitude: '23.0',
    );

    test('默认构造仅 controller 必填，其余为空字符串', () {
      final s = FaceToFaceState(textEditingController: controller);
      expect(s.errorInfo, '');
      expect(s.resultData, '');
      expect(s.longitude, '');
      expect(s.latitude, '');
      expect(s.textEditingController, same(controller));
    });

    test('copyWith 不传参数 → 所有字段保持不变', () {
      final s = base();
      final c = s.copyWith();
      expect(c.errorInfo, 'e0');
      expect(c.resultData, 'r0');
      expect(c.longitude, '113.0');
      expect(c.latitude, '23.0');
      expect(c.textEditingController, same(controller));
    });

    test('copyWith 单字段覆盖 → 仅该字段变化，其余不动', () {
      final s = base();
      final c = s.copyWith(resultData: 'r1');
      expect(c.resultData, 'r1');
      expect(c.errorInfo, 'e0');
      expect(c.longitude, '113.0');
      expect(c.latitude, '23.0');
    });

    test('copyWith 多字段覆盖经纬度 → 同步更新', () {
      final s = base();
      final c = s.copyWith(longitude: '0', latitude: '0', errorInfo: '');
      expect(c.longitude, '0');
      expect(c.latitude, '0');
      expect(c.errorInfo, '');
      // 未覆盖字段保留
      expect(c.resultData, 'r0');
    });

    test('copyWith 替换 controller 引用', () {
      final s = base();
      final other = NumericKeypadController('9');
      final c = s.copyWith(textEditingController: other);
      expect(c.textEditingController, same(other));
      expect(c.textEditingController, isNot(same(controller)));
    });
  });
}
