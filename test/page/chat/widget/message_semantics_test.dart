/// 非文字消息的语义包装契约。
///
/// 覆盖范围说明（诚实边界）：本文件只钉 [semanticMessage] 自身的配置，
/// **不能**证明 chat_page 的四个 builder 确实调用了它——ChatPage 复杂度过高，
/// 在 widget 测试里 mount 不起来（原因见 chat_page_smoke_test.dart 顶部注释）。
/// 那一层要等 ChatPage 注入式测试 sprint。
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_semantics.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isSentByMe,
    Widget child = const SizedBox(width: 40, height: 40),
  }) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: semanticMessage(
              isSentByMe: isSentByMe,
              kind: t.chat.image,
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('声明为按钮并读出方向与类型', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, isSentByMe: true);
    final node = tester.getSemantics(find.byType(SizedBox).first);
    expect(
      node.hasFlag(SemanticsFlag.isButton),
      isTrue,
      reason: '图片/语音消息是可点的，读屏得知道它能点',
    );
    expect(node.label, '${t.main.sentByMe}${t.chat.image}');

    handle.dispose();
  });

  testWidgets('对方发来的消息读出的方向不同', (tester) async {
    final handle = tester.ensureSemantics();

    await pump(tester, isSentByMe: false);
    expect(
      tester.getSemantics(find.byType(SizedBox).first).label,
      '${t.chat.myReceivedTab}${t.chat.image}',
      reason: '分不清谁发的，读屏用户就没法跟上对话',
    );

    handle.dispose();
  });

  testWidgets('不吞掉子节点自带的信息', (tester) async {
    final handle = tester.ensureSemantics();

    // 文件消息的文件名、语音消息的时长都在子树里，用 ExcludeSemantics
    // 包住的话这些信息就全没了。
    await pump(tester, isSentByMe: false, child: const Text('report.pdf'));
    expect(find.text('report.pdf'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('report.pdf')).label,
      contains('report.pdf'),
    );

    handle.dispose();
  });
}
