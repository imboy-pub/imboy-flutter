/// Tests for `lib/component/helper/string.dart` StringHelper.
///
/// 覆盖：
///   - chunk(s, size) 切片：完整切、最后一片不满、size > s.length、空字符串
///   - ext(url) 取扩展名：标准、含 ?query、JPG → JPEG 归一化、无 . / 空 url 兜底
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/string.dart';

void main() {
  group('StringHelper.chunk', () {
    test('整除 → 等长切片', () {
      expect(StringHelper.chunk('abcdef', 2), ['ab', 'cd', 'ef']);
    });

    test('不整除 → 末尾片为余数长度', () {
      expect(StringHelper.chunk('abcdefg', 3), ['abc', 'def', 'g']);
    });

    test('chunkSize > s.length → 单一片为整 s', () {
      expect(StringHelper.chunk('abc', 10), ['abc']);
    });

    test('空字符串 → 空列表', () {
      expect(StringHelper.chunk('', 4), <String>[]);
    });

    test('chunkSize = s.length → 单一片', () {
      expect(StringHelper.chunk('abc', 3), ['abc']);
    });

    test('chunkSize = 1 → 每个字符独立', () {
      expect(StringHelper.chunk('abc', 1), ['a', 'b', 'c']);
    });
  });

  group('StringHelper.ext', () {
    test('标准 .png → "png"', () {
      expect(StringHelper.ext('https://x.com/a.png'), 'png');
    });

    test('JPG 归一化为 JPEG（大小写不敏感）', () {
      expect(StringHelper.ext('https://x.com/a.JPG'), 'JPEG');
      expect(StringHelper.ext('https://x.com/a.jpg'), 'JPEG');
    });

    test('jpeg 不被改回 JPG（保持原样）', () {
      // 实现仅在 toUpperCase=='JPG' 时改写为 'JPEG'，
      // 已是 jpeg 的不会被改写
      expect(StringHelper.ext('https://x.com/a.jpeg'), 'jpeg');
    });

    test('含 ?query 参数 → 返回 query 前的扩展名', () {
      expect(StringHelper.ext('https://x.com/a.mp4?token=abc'), 'mp4');
    });

    test('整个 url 没有任何 . → 空字符串', () {
      // 注意：URL 'https://x.com/...' 在 host 段就含 .（x.com），不算"无点"
      // 真正无点的输入：纯文件名/路径段
      expect(StringHelper.ext('file_no_dot'), '');
    });

    test('空 url → 空字符串', () {
      expect(StringHelper.ext(''), '');
    });

    test('多个点 → 取最后一个 . 后部分', () {
      expect(StringHelper.ext('https://x.com/a.b.c.gif'), 'gif');
    });
  });
}
