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
import 'package:imboy/service/message_type_constants.dart';

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

  // ── messageKindLabel：CustomMessage 那 16 个插件类型的读法 ──
  // 这条链此前完全没有语义标签，读屏用户翻聊天记录时位置/名片/红包/转账/
  // 通话记录全是哑的。下面钉住每个类型都念得出专属名字。

  test('未知类型 → 落到自定义消息兜底，不返回空串', () {
    expect(messageKindLabel('no_such_type'), t.chat.customMessage);
    expect(messageKindLabel(''), t.chat.customMessage);
  });

  test('image 与 imageMulti 念同一个"图片"', () {
    expect(messageKindLabel(MessageType.image), t.chat.image);
    expect(messageKindLabel(MessageType.imageMulti), t.chat.image);
  });

  test('每个经 CustomMessage 渲染的类型都有专属读法（不落兜底）', () {
    // text / textStream 走 FlyerChatTextMessage 与 mapper 归一，不经此链；
    // custom 本身就是兜底语义。
    const rendered = [
      MessageType.image,
      MessageType.imageMulti,
      MessageType.voice,
      MessageType.video,
      MessageType.file,
      MessageType.location,
      MessageType.expression,
      MessageType.quote,
      MessageType.visitCard,
      MessageType.redPacket,
      MessageType.transfer,
      MessageType.webrtcAudio,
      MessageType.webrtcVideo,
      MessageType.groupSchedule,
      MessageType.unsupported,
    ];

    for (final type in rendered) {
      final label = messageKindLabel(type);
      expect(label, isNotEmpty, reason: '$type 没有读法');
      expect(
        label,
        isNot(t.chat.customMessage),
        reason: '$type 落到了兜底读法，读屏念不出具体类型',
      );
    }
  });

  test('通话记录不与语音/视频消息混淆', () {
    expect(messageKindLabel(MessageType.webrtcAudio), t.common.voiceCall);
    expect(messageKindLabel(MessageType.voice), t.chat.voiceMessage);
    expect(
      messageKindLabel(MessageType.webrtcAudio),
      isNot(messageKindLabel(MessageType.voice)),
    );
    expect(
      messageKindLabel(MessageType.webrtcVideo),
      isNot(messageKindLabel(MessageType.video)),
    );
  });
}
