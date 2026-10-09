import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
import 'package:flyer_chat_text_stream_message/flyer_chat_text_stream_message.dart';
import 'package:imboy/component/chat/chat_web_links.dart';
// FlyerChatTextMessage consumes these providers from its own provider dependency.
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';

void main() {
  test('只投影带端口网页链接，消息原文与标识保持不变', () {
    const raw =
        '访问 http://127.0.0.1:29861/readyz，或 https://oa.example.test:8443/a。';
    const message = TextMessage(id: 'm1', authorId: 'u1', text: raw);
    final projected = ChatWebLinks.project(message);
    expect(
      projected.text,
      '访问 <http://127.0.0.1:29861/readyz>，或 <https://oa.example.test:8443/a>。',
    );
    expect(message.text, raw);
    expect(projected.id, message.id);
    expect(
      ChatWebLinks.project(message.copyWith(text: 'https://example.test/a')),
      message.copyWith(text: 'https://example.test/a'),
    );
  });

  test('已有链接、图片、代码和不可用网址不改写', () {
    for (final raw in [
      '[网页](http://localhost:8080/a)',
      '![图片](http://localhost:8080/a)',
      '<http://localhost:8080/a>',
      '`http://localhost:8080/a`',
      '```\nhttp://localhost:8080/a\n```',
      '```\nhttp://localhost:8080/a',
      '~~~\nhttp://localhost:8080/a\n~~~',
      'javascript://localhost:8080/a',
      'http://:8080/a',
      'http://localhost:0/a',
      'http://localhost:65536/a',
      'http://user:secret@localhost:8080/a',
    ]) {
      expect(ChatWebLinks.projectText(raw), raw, reason: raw);
    }
    expect(
      ChatWebLinks.projectText(
        '`http://localhost:8080/a` http://localhost:8080/b',
      ),
      '`http://localhost:8080/a` <http://localhost:8080/b>',
    );
    expect(
      ChatWebLinks.projectText('见 http://localhost:8080/a(b)).'),
      '见 <http://localhost:8080/a(b)>).',
    );
  });

  test('完成流消息仅做显示投影，其他状态原样保留', () {
    const completed = StreamStateCompleted('http://localhost:8080/a');
    expect(
      (ChatWebLinks.projectStream(completed) as StreamStateCompleted).finalText,
      '<http://localhost:8080/a>',
    );
    expect(completed.finalText, 'http://localhost:8080/a');
    const loading = StreamStateLoading();
    expect(identical(ChatWebLinks.projectStream(loading), loading), isTrue);
  });

  for (final url in [
    'http://127.0.0.1:29861/readyz',
    'https://oa.example.test:8443/a?x=1&y=2',
    'http://localhost:8080/a(b)',
  ]) {
    testWidgets('实际聊天组件点击回调保持原始 URL：$url', (tester) async {
      final opened = <String>[];
      final message = TextMessage(id: 'm1', authorId: 'u1', text: url);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ChatTheme>.value(value: ChatTheme.light()),
            Provider<UserID>.value(value: 'u2'),
            Provider<Builders>.value(value: const Builders()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FlyerChatTextMessage(
                message: ChatWebLinks.project(message),
                index: 0,
                showTime: false,
                showStatus: false,
                onLinkTap: (value, title) => opened.add(value),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text(url, findRichText: true));
      await tester.pump();
      expect(opened, [url]);
      expect(message.text, url);
    });
  }
}
