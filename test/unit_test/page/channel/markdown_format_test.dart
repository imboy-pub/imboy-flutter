// 频道撰写「格式工具条」纯函数光标数学测试（方案三 D2）。
//
// 光标数学是本批易错点，这里穷举覆盖：
//   - applyInlineWrap：有/无选区、光标落点、空文本、非法选区
//   - applyLinePrefix：多行文本定位正确行、行首插入、选区右移
//   - applyLink：模板拼接、url 占位符选中落点、有/无选区
//
// 运行方式 / How to run:
//   flutter test test/page/channel/markdown_format_test.dart

import 'package:flutter/widgets.dart' show TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/channel/widgets/markdown_format.dart';

void main() {
  group('applyInlineWrap - 无选区', () {
    test('空文本插入 marker 对，光标落中间', () {
      final r = applyInlineWrap(
        '',
        const TextSelection.collapsed(offset: 0),
        '**',
      );
      expect(r.text, '****');
      expect(r.selection.isCollapsed, isTrue);
      expect(r.selection.baseOffset, 2); // 两个 * 之间
    });

    test('文本中间插入，光标落两 marker 之间', () {
      final r = applyInlineWrap(
        'ab',
        const TextSelection.collapsed(offset: 1),
        '*',
      );
      expect(r.text, 'a**b');
      expect(r.selection.baseOffset, 2); // a* | *b
    });

    test('行内代码单反引号', () {
      final r = applyInlineWrap(
        'code',
        const TextSelection.collapsed(offset: 4),
        '`',
      );
      expect(r.text, 'code``');
      expect(r.selection.baseOffset, 5);
    });

    test('非法选区（offset -1）退化到文末插入', () {
      final r = applyInlineWrap(
        'hi',
        const TextSelection.collapsed(offset: -1),
        '~~',
      );
      expect(r.text, 'hi~~~~');
      expect(r.selection.baseOffset, 4); // 2(len) + 2(marker)
    });
  });

  group('applyInlineWrap - 有选区', () {
    test('包裹选区，光标落包裹文本末尾', () {
      // "hello world"，选中 "world" [6,11)
      final r = applyInlineWrap(
        'hello world',
        const TextSelection(baseOffset: 6, extentOffset: 11),
        '**',
      );
      expect(r.text, 'hello **world**');
      expect(r.selection.isCollapsed, isTrue);
      expect(r.selection.baseOffset, 15); // 整段末尾
    });

    test('反向选区（base>extent）同样正确包裹', () {
      final r = applyInlineWrap(
        'abcd',
        const TextSelection(baseOffset: 3, extentOffset: 1), // 选中 "bc"
        '*',
      );
      expect(r.text, 'a*bc*d');
      expect(r.selection.baseOffset, 5); // 1 + 1 + 2 + 1
    });

    test('全选包裹', () {
      final r = applyInlineWrap(
        'x',
        const TextSelection(baseOffset: 0, extentOffset: 1),
        '~~',
      );
      expect(r.text, '~~x~~');
      expect(r.selection.baseOffset, 5);
    });
  });

  group('applyLinePrefix', () {
    test('单行行首插入标题前缀', () {
      final r = applyLinePrefix(
        'title',
        const TextSelection.collapsed(offset: 5),
        '# ',
      );
      expect(r.text, '# title');
      expect(r.selection.baseOffset, 7); // 5 + 2
    });

    test('多行文本：只在光标所在行行首插入', () {
      // "aaa\nbbb\nccc"，光标在第二行 bbb 内 offset 5
      const text = 'aaa\nbbb\nccc';
      final r = applyLinePrefix(
        text,
        const TextSelection.collapsed(offset: 5),
        '- ',
      );
      expect(r.text, 'aaa\n- bbb\nccc');
      expect(r.selection.baseOffset, 7); // 5 + 2
    });

    test('光标在行首（换行符后）仍定位到本行', () {
      const text = 'aaa\nbbb';
      // offset 4 = bbb 的 b 之前
      final r = applyLinePrefix(
        text,
        const TextSelection.collapsed(offset: 4),
        '> ',
      );
      expect(r.text, 'aaa\n> bbb');
      expect(r.selection.baseOffset, 6);
    });

    test('光标在换行符前（上一行行尾）作用于上一行', () {
      const text = 'aaa\nbbb';
      // offset 3 = aaa 之后、\n 之前
      final r = applyLinePrefix(
        text,
        const TextSelection.collapsed(offset: 3),
        '# ',
      );
      expect(r.text, '# aaa\nbbb');
      expect(r.selection.baseOffset, 5);
    });

    test('空文本插入前缀', () {
      final r = applyLinePrefix(
        '',
        const TextSelection.collapsed(offset: 0),
        '## ',
      );
      expect(r.text, '## ');
      expect(r.selection.baseOffset, 3);
    });

    test('选区两端整体右移前缀长度', () {
      // "hello" 选中 [1,4)
      final r = applyLinePrefix(
        'hello',
        const TextSelection(baseOffset: 1, extentOffset: 4),
        '- ',
      );
      expect(r.text, '- hello');
      expect(r.selection.baseOffset, 3); // 1 + 2
      expect(r.selection.extentOffset, 6); // 4 + 2
    });
  });

  group('applyLink', () {
    test('无选区：插入占位模板，url 被选中待填', () {
      final r = applyLink('', const TextSelection.collapsed(offset: 0));
      expect(r.text, '[link](url)');
      // url 落点：'[' + 'link'(4) + '](' = 1+4+2 = 7
      expect(r.selection.baseOffset, 7);
      expect(r.selection.extentOffset, 10); // 7 + 3('url')
      expect(r.text.substring(r.selection.start, r.selection.end), 'url');
    });

    test('有选区：选中文字当链接文字，url 被选中', () {
      // "see here"，选中 "here" [4,8)
      final r = applyLink(
        'see here',
        const TextSelection(baseOffset: 4, extentOffset: 8),
      );
      expect(r.text, 'see [here](url)');
      // urlStart = 4 + 1 + 4('here') + 2 = 11
      expect(r.selection.baseOffset, 11);
      expect(r.selection.extentOffset, 14);
      expect(r.text.substring(r.selection.start, r.selection.end), 'url');
    });

    test('自定义占位符', () {
      final r = applyLink(
        '',
        const TextSelection.collapsed(offset: 0),
        linkTextPlaceholder: '链接文字',
        urlPlaceholder: '网址',
      );
      expect(r.text, '[链接文字](网址)');
      // urlStart = 0 + 1 + 4 + 2 = 7
      expect(r.selection.baseOffset, 7);
      expect(r.text.substring(r.selection.start, r.selection.end), '网址');
    });

    test('非法选区退化文末插入', () {
      final r = applyLink('abc', const TextSelection.collapsed(offset: -1));
      expect(r.text, 'abc[link](url)');
      expect(r.selection.baseOffset, 3 + 7);
    });
  });
}
