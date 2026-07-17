/// Tests for `lib/page/moment/moment_utils.dart`
/// `normalizeMomentLocation` / `normalizeMomentAtUids`.
///
/// 朋友圈"所在位置 + @提醒谁看"数据层读回（方案 E1）。动态帖以 raw
/// `Map<String, dynamic>` 流转（无 typed model），这两个纯函数做防御式读取。
///
/// 契约：
///   - location：非 Map / 无 name → null；有 name → 复制 map（防别名污染）
///   - at_uids：非 List → const []；逐项转 String；空串过滤
///   - 向后兼容：旧帖缺字段 → null / []（不崩）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_utils.dart';

void main() {
  group('normalizeMomentLocation', () {
    test('null（旧帖无位置）→ null', () {
      expect(normalizeMomentLocation(null), isNull);
    });

    test('非 Map（脏数据）→ null', () {
      expect(normalizeMomentLocation('somewhere'), isNull);
      expect(normalizeMomentLocation(42), isNull);
      expect(normalizeMomentLocation(['a', 'b']), isNull);
    });

    test('无 name（无有效位置）→ null', () {
      expect(normalizeMomentLocation(<String, dynamic>{'lng': 1.0}), isNull);
      expect(normalizeMomentLocation(<String, dynamic>{'name': ''}), isNull);
    });

    test('含 name → 返回 map（保留经纬度/地址）', () {
      final out = normalizeMomentLocation(<String, dynamic>{
        'name': 'Cafe',
        'lng': 121.4,
        'lat': 31.2,
        'address': '某街1号',
      });
      expect(out, isNotNull);
      expect(out!['name'], 'Cafe');
      expect(out['lng'], 121.4);
      expect(out['address'], '某街1号');
    });

    test('返回的是输入 map 的副本（修改返回值不污染输入）', () {
      final input = <String, dynamic>{'name': 'Cafe'};
      final out = normalizeMomentLocation(input);
      out!['name'] = 'mutated';
      expect(input['name'], 'Cafe');
    });
  });

  group('normalizeMomentAtUids', () {
    test('null（旧帖无 @）→ 空列表', () {
      expect(normalizeMomentAtUids(null), isEmpty);
    });

    test('非 List → 空列表', () {
      expect(normalizeMomentAtUids('2002'), isEmpty);
      expect(normalizeMomentAtUids(<String, dynamic>{'k': 'v'}), isEmpty);
    });

    test('integer 元素（TSID 传输）→ 转 String', () {
      final out = normalizeMomentAtUids([2002, 2003]);
      expect(out, ['2002', '2003']);
    });

    test('String 元素 → 原样保留', () {
      expect(normalizeMomentAtUids(['2002', '2003']), ['2002', '2003']);
    });

    test('空串/无效项被过滤', () {
      expect(normalizeMomentAtUids([2002, '', null]), ['2002']);
    });

    test('返回 non-growable List', () {
      final out = normalizeMomentAtUids([2002]);
      expect(() => out.add('x'), throwsUnsupportedError);
    });
  });
}
