// 频道 markdown 基础（D1）测试
//
// - stripMarkdown 纯函数：bold / heading / list / quote / link / code 去噪
// - channelMarkdownBody：能把 `**bold**` / `# 标题` pump 成富文本
//
// 运行方式 / How to run:
//   flutter test test/page/channel/channel_markdown_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_markdown.dart';

void main() {
  group('stripMarkdown', () {
    test('剥离粗体/斜体标记，保留文字', () {
      expect(stripMarkdown('这是**重点**内容'), '这是重点内容');
      expect(stripMarkdown('斜体*强调*文字'), '斜体强调文字');
      expect(stripMarkdown('~~删除~~线'), '删除线');
    });

    test('剥离标题井号', () {
      expect(stripMarkdown('# 一级标题'), '一级标题');
      expect(stripMarkdown('### 三级标题'), '三级标题');
    });

    test('剥离无序/有序列表标记', () {
      expect(stripMarkdown('- 苹果\n- 香蕉'), '苹果\n香蕉');
      expect(stripMarkdown('1. 第一\n2. 第二'), '第一\n第二');
    });

    test('剥离引用标记', () {
      expect(stripMarkdown('> 一句引用'), '一句引用');
    });

    test('链接只保留可读文字', () {
      expect(stripMarkdown('点击[官网](https://imboy.pub)看看'), '点击官网看看');
    });

    test('图片只保留 alt 文字', () {
      expect(stripMarkdown('封面![大图](https://x/a.png)结束'), '封面大图结束');
    });

    test('行内代码保留内容', () {
      expect(stripMarkdown('运行 `flutter test` 命令'), '运行 flutter test 命令');
    });

    test('纯文本恒等（向后兼容）', () {
      const plain = '这是一段普通频道正文，没有任何标记。';
      expect(stripMarkdown(plain), plain);
    });

    test('分隔线整行去掉', () {
      expect(stripMarkdown('上文\n---\n下文'), '上文\n\n下文');
    });
  });

  group('channelMarkdownBody', () {
    testWidgets('渲染粗体与标题为富文本', (tester) async {
      await tester.pumpWidget(
        TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    channelMarkdownBody(context, '# 标题\n\n这是**加粗**正文'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
      // 富文本拆成多个 widget，用 textContaining 校验文字落地
      expect(find.textContaining('标题'), findsWidgets);
      expect(find.textContaining('加粗'), findsWidgets);
    });
  });
}
