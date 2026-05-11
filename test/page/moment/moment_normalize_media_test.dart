/// Tests for `lib/page/moment/moment_utils.dart` `normalizeMedia`.
///
/// 纯函数：把任意 raw 输入归一化为 `List<Map<String, dynamic>>`（顶层 List
/// 内每个元素都是 String 索引的 dynamic Map）。
///
/// 契约：
///   - 非 List → 返回 const [] 空列表
///   - List 内非 Map 元素被静默过滤（脏数据兜底）
///   - List 内的 Map 元素被复制（防外部别名后变更污染）
///   - 返回 non-growable List（防业务侧 add 后影响下游）
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_utils.dart';

void main() {
  group('normalizeMedia non-list inputs', () {
    test('null → 空列表', () {
      expect(normalizeMedia(null), isEmpty);
    });

    test('String → 空列表', () {
      expect(normalizeMedia('not a list'), isEmpty);
    });

    test('int → 空列表', () {
      expect(normalizeMedia(42), isEmpty);
    });

    test('Map（不是 List）→ 空列表', () {
      expect(normalizeMedia(<String, dynamic>{'k': 'v'}), isEmpty);
    });
  });

  group('normalizeMedia list inputs', () {
    test('空 list → 空 list', () {
      expect(normalizeMedia(const <Map<String, dynamic>>[]), isEmpty);
    });

    test('全 Map 元素 → 全部保留', () {
      final out = normalizeMedia([
        {'url': 'a.jpg'},
        {'url': 'b.jpg', 'type': 'image'},
      ]);
      expect(out.length, 2);
      expect(out[0]['url'], 'a.jpg');
      expect(out[1]['type'], 'image');
    });

    test('混合 Map / 非 Map 元素 → 只保留 Map', () {
      final out = normalizeMedia([
        {'url': 'ok.jpg'},
        'string_garbage',
        42,
        null,
        <String>['nested', 'list'],
        {'url': 'also_ok.jpg'},
      ]);
      expect(out.length, 2);
      expect(out[0]['url'], 'ok.jpg');
      expect(out[1]['url'], 'also_ok.jpg');
    });

    test('全非 Map → 空列表', () {
      expect(normalizeMedia([1, 'a', null, true]), isEmpty);
    });
  });

  group('normalizeMedia output isolation (immutability)', () {
    test('返回的 Map 是输入 Map 的副本（修改返回值不影响输入）', () {
      final input = <String, dynamic>{'url': 'a.jpg'};
      final out = normalizeMedia([input]);
      out.first['url'] = 'mutated.jpg';
      expect(input['url'], 'a.jpg',
          reason: '返回的是 Map.from 复制，原 Map 必须保持不变');
    });

    test('返回的 List 是 non-growable（防意外 add 调用）', () {
      final out = normalizeMedia([
        {'url': 'a.jpg'},
      ]);
      expect(
        () => out.add({'url': 'x'}),
        throwsUnsupportedError,
        reason: 'normalizeMedia 用 toList(growable: false) 锁定长度',
      );
    });

    test('Map 元素含嵌套结构 → 浅拷贝（嵌套引用共享，但顶层 key/val 独立）', () {
      final nestedList = <String>['x', 'y'];
      final input = <String, dynamic>{
        'url': 'a.jpg',
        'tags': nestedList,
      };
      final out = normalizeMedia([input]);
      // 浅拷贝：nestedList 还是同一个引用
      expect(identical(out.first['tags'], nestedList), isTrue);
      // 但顶层 key 'url' 修改不影响原 input
      out.first['url'] = 'changed';
      expect(input['url'], 'a.jpg');
    });
  });
}
