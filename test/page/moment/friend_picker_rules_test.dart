/// Slice B-1 纯函数 TDD：朋友圈好友选择器决策内核。
///
/// 零外部依赖（不引 flutter_test 的 widget tester，也不碰 sqflite）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_friend_picker/friend_picker_rules.dart';

void main() {
  group('togglePickedUid', () {
    test('空集加入新 uid', () {
      final result = togglePickedUid(<String>{}, 'u1');
      expect(result, {'u1'});
    });

    test('已存在的 uid → 移除', () {
      final result = togglePickedUid({'u1', 'u2'}, 'u1');
      expect(result, {'u2'});
    });

    test('不存在的 uid → 加入', () {
      final result = togglePickedUid({'u1'}, 'u2');
      expect(result, {'u1', 'u2'});
    });

    test('空串 → 原样返回', () {
      final result = togglePickedUid({'u1'}, '');
      expect(result, {'u1'});
    });

    test('全空白 → 原样返回', () {
      final result = togglePickedUid({'u1'}, '   ');
      expect(result, {'u1'});
    });

    test('前后空白会被 trim', () {
      final result = togglePickedUid(<String>{}, '  u1  ');
      expect(result, {'u1'});
    });

    test('返回独立副本（不修改入参）', () {
      final input = {'u1'};
      togglePickedUid(input, 'u2');
      expect(input, {'u1'}); // 原集合未被修改
    });
  });

  group('applyTagToggle', () {
    test('select=true：加入标签下全部 uid', () {
      final result = applyTagToggle(
        {'u1'},
        ['u2', 'u3'],
        select: true,
      );
      expect(result, {'u1', 'u2', 'u3'});
    });

    test('select=false：移除标签下全部 uid', () {
      final result = applyTagToggle(
        {'u1', 'u2', 'u3'},
        ['u2', 'u3'],
        select: false,
      );
      expect(result, {'u1'});
    });

    test('select=true：已存在的 uid 不重复添加', () {
      final result = applyTagToggle(
        {'u1', 'u2'},
        ['u2', 'u3'],
        select: true,
      );
      expect(result, {'u1', 'u2', 'u3'});
    });

    test('select=false：不存在的 uid 忽略', () {
      final result = applyTagToggle(
        {'u1'},
        ['u2', 'u3'],
        select: false,
      );
      expect(result, {'u1'});
    });

    test('tagUids 中的空白元素被忽略', () {
      final result = applyTagToggle(
        <String>{},
        ['u1', '', '   ', 'u2'],
        select: true,
      );
      expect(result, {'u1', 'u2'});
    });

    test('空的 tagUids → 原样返回副本', () {
      final result = applyTagToggle(
        {'u1'},
        const [],
        select: true,
      );
      expect(result, {'u1'});
    });

    test('返回独立副本（不修改入参）', () {
      final input = {'u1'};
      applyTagToggle(input, ['u2'], select: true);
      expect(input, {'u1'});
    });
  });

  group('sortUidsForPayload', () {
    test('空集 → 空 list', () {
      expect(sortUidsForPayload(<String>{}), isEmpty);
    });

    test('字典序升序排序', () {
      final result = sortUidsForPayload({'u3', 'u1', 'u2'});
      expect(result, ['u1', 'u2', 'u3']);
    });

    test('过滤空白和空串', () {
      final result = sortUidsForPayload({'u1', '', '   ', 'u2'});
      expect(result, ['u1', 'u2']);
    });

    test('trim 后去重', () {
      final result = sortUidsForPayload({'u1', '  u1  ', 'u2'});
      expect(result, ['u1', 'u2']);
    });

    test('确定性：多次调用同输入 → 同输出', () {
      final input = {'u3', 'u1', 'u2'};
      final r1 = sortUidsForPayload(input);
      final r2 = sortUidsForPayload(input);
      expect(r1, r2);
    });

    test('TSID 数字字符串按字典序排（非数值序）', () {
      // TSID 长度固定，字典序与数值序等价；这里记录约束
      final result = sortUidsForPayload({'1000', '200', '30'});
      expect(result, ['1000', '200', '30']); // 字典序：'1' < '2' < '3'
    });
  });

  group('resolveTagSelectionState', () {
    test('标签全部在选中集 → all', () {
      final s = resolveTagSelectionState({'u1', 'u2', 'u3'}, ['u1', 'u2']);
      expect(s, TagSelectionState.all);
    });

    test('标签部分在选中集 → partial', () {
      final s = resolveTagSelectionState({'u1'}, ['u1', 'u2']);
      expect(s, TagSelectionState.partial);
    });

    test('标签全部不在选中集 → none', () {
      final s = resolveTagSelectionState({'u3'}, ['u1', 'u2']);
      expect(s, TagSelectionState.none);
    });

    test('空标签 → none', () {
      final s = resolveTagSelectionState({'u1'}, const []);
      expect(s, TagSelectionState.none);
    });

    test('标签全为空白 → none（归一化后为空集）', () {
      final s = resolveTagSelectionState({'u1'}, ['', '   ']);
      expect(s, TagSelectionState.none);
    });

    test('标签含重复 uid → 仍按去重后判定', () {
      final s = resolveTagSelectionState({'u1'}, ['u1', 'u1']);
      expect(s, TagSelectionState.all);
    });
  });
}
