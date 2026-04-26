import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show AudioMessage, FileMessage, ImageMessage, Message, TextMessage;
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/quote_tips.dart';
import 'package:imboy/store/model/message_model.dart';

/// QuoteTipsWidget 引用消息提示条 widget 契约测试
///
/// QuoteTipsWidget 是 StatelessWidget，仅依赖 props（title / message / close）+
/// Theme + i18n（无 Riverpod / EventBus / SqliteService 依赖）。
///
/// 覆盖：
///   - message=null → 隐藏（AnimatedOpacity invisible + SizedBox.shrink）
///   - message=TextMessage → 显示文本内容
///   - message=ImageMessage → 显示图标 + ImageView
///   - title 渲染
///   - close 按钮 tap 触发回调
///   - close=null → 不抛错
Future<void> _pump(
  WidgetTester tester, {
  required String title,
  required Message? message,
  VoidCallback? close,
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: QuoteTipsWidget(
            title: title,
            message: message,
            close: close,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('QuoteTipsWidget hidden state', () {
    testWidgets('message=null → 隐藏（AnimatedOpacity 0.0 + SizedBox.shrink）',
        (tester) async {
      await _pump(tester, title: '回复张三', message: null);

      // 隐藏态仍渲染 AnimatedOpacity 但 opacity=0；body 是 SizedBox.shrink
      expect(find.byType(AnimatedOpacity), findsOneWidget);
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 0.0);

      // 标题不渲染（隐藏态走 SizedBox.shrink 分支）
      expect(find.text('回复张三'), findsNothing);
    });
  });

  group('QuoteTipsWidget text message', () {
    testWidgets('TextMessage → 显示文本内容 + title', (tester) async {
      const text = TextMessage(
        id: 'msg_1',
        authorId: 'u_1',
        text: '你好世界',
      );

      await _pump(tester, title: '回复张三', message: text);

      expect(find.text('回复张三'), findsOneWidget);
      expect(find.text('你好世界'), findsOneWidget);

      // 显示态：AnimatedOpacity opacity=1.0
      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(opacity.opacity, 1.0);
    });

    testWidgets('TextMessage → close icon (close_rounded) 渲染', (tester) async {
      const text = TextMessage(
        id: 'msg_1',
        authorId: 'u_1',
        text: 'Hi',
      );

      await _pump(tester, title: 'Reply', message: text, close: () {});
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('close button tap 触发 close 回调', (tester) async {
      var closeCount = 0;
      const text = TextMessage(
        id: 'msg_1',
        authorId: 'u_1',
        text: 'Hi',
      );

      await _pump(
        tester,
        title: 'Reply',
        message: text,
        close: () => closeCount++,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(closeCount, 1);
    });

    testWidgets('close=null → tap close icon 不抛错', (tester) async {
      const text = TextMessage(
        id: 'msg_1',
        authorId: 'u_1',
        text: 'Hi',
      );

      await _pump(tester, title: 'Reply', message: text);
      // close 为 null 时 InkWell.onTap=null，tap 仍能完成不崩
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      // 没有任何 callback 被调用，但也无异常
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });

  group('QuoteTipsWidget image message', () {
    testWidgets('ImageMessage → 显示图片 icon (Icons.image)', (tester) async {
      const image = ImageMessage(
        id: 'msg_2',
        authorId: 'u_1',
        source: 'https://example.com/test.png',
        size: 1024,
      );

      await _pump(tester, title: 'Reply', message: image);

      expect(find.byIcon(Icons.image), findsOneWidget);
      // title 仍渲染
      expect(find.text('Reply'), findsOneWidget);
    });
  });

  group('QuoteTipsWidget file/audio chat_core types', () {
    testWidgets('FileMessage → 显示 attach_file icon + "[文件] (size)" + name',
        (tester) async {
      const file = FileMessage(
        id: 'msg_f',
        authorId: 'u_1',
        source: 'https://example.com/doc.pdf',
        name: 'report.pdf',
        size: 2048,
      );

      await _pump(tester, title: 'Reply', message: file);

      expect(find.byIcon(Icons.attach_file), findsOneWidget);
      // 文件名渲染
      expect(find.text('report.pdf'), findsOneWidget);
      // i18n: file = "文件"，size 2048 bytes 通过 formatBytes 格式化
      // 不锁定具体 size 字符串（formatBytes 实现可能变），只验证含 [文件] 前缀
      expect(find.textContaining('[${t.file}]'), findsOneWidget);
    });

    testWidgets('AudioMessage → 显示 mic icon + "[语音消息]"', (tester) async {
      const audio = AudioMessage(
        id: 'msg_a',
        authorId: 'u_1',
        source: 'https://example.com/voice.aac',
        duration: Duration(seconds: 5),
      );

      await _pump(tester, title: 'Reply', message: audio);

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text('[${t.voiceMessage}]'), findsOneWidget);
    });
  });

  group('QuoteTipsWidget metadata-driven types', () {
    /// 构造一个基础 TextMessage 但 metadata 标记不同 msg_type 触发对应 body 分支
    TextMessage buildMetaMsg({Map<String, dynamic>? metadata}) {
      return TextMessage(
        id: 'msg_meta',
        authorId: 'u_1',
        text: 'placeholder text',
        metadata: metadata,
      );
    }

    testWidgets('msg_type=quote → 显示 format_quote icon + 引用文本',
        (tester) async {
      final msg = buildMetaMsg(metadata: {
        'msg_type': 'quote',
        'quote_text': '上一条消息内容',
      });
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.format_quote), findsOneWidget);
      // 包含 [引用] 前缀 + 引用文本
      expect(
        find.textContaining('[${t.quote}] 上一条消息内容'),
        findsOneWidget,
      );
    });

    testWidgets('msg_type=voice (metadata 路径) → 显示 mic icon + 时长',
        (tester) async {
      // duration_ms = 3500 → 3.5"
      final msg = buildMetaMsg(metadata: {
        'msg_type': 'voice',
        'duration_ms': 3500,
      });
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.textContaining('[${t.voiceMessage}]'), findsOneWidget);
      expect(find.textContaining('3.5'), findsOneWidget);
    });

    testWidgets('msg_type=location → 显示 location_on icon + "[位置] title"',
        (tester) async {
      final msg = buildMetaMsg(metadata: {
        'msg_type': 'location',
        'title': '北京天安门',
      });
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.location_on), findsOneWidget);
      expect(
        find.textContaining('[${t.location}] 北京天安门'),
        findsOneWidget,
      );
    });

    testWidgets('msg_type=video → 显示 videocam icon + "[视频]"',
        (tester) async {
      final msg = buildMetaMsg(metadata: {
        'msg_type': 'video',
      });
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.videocam), findsOneWidget);
      // i18n: video = "视频"
      expect(find.textContaining('[${t.video}]'), findsOneWidget);
    });

    testWidgets('msg_type=visitCard → 显示 person icon + "[名片] title"',
        (tester) async {
      final msg = buildMetaMsg(metadata: {
        'msg_type': 'visitCard',
        'title': '李四 (imboy_user)',
      });
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(
        find.textContaining('[${t.businessCard}] 李四 (imboy_user)'),
        findsOneWidget,
      );
    });
  });

  group('QuoteTipsWidget revoked status (priority over msg_type)', () {
    testWidgets('status=peerRevoked (30) → 显示 block icon + "消息已撤回"',
        (tester) async {
      final msg = TextMessage(
        id: 'msg_rev',
        authorId: 'u_1',
        text: '原消息内容（被撤回）',
        metadata: {
          'msg_type': 'text',
          'status': IMBoyMessageStatus.peerRevoked, // 30
        },
      );
      await _pump(tester, title: 'Reply', message: msg);

      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.text(t.messageRevoked), findsOneWidget);
    });

    testWidgets(
      'status=myRevoked (31) 且 msg_type=video → 仍走撤回分支（status 优先）',
      (tester) async {
        final msg = TextMessage(
          id: 'msg_rev_video',
          authorId: 'u_1',
          text: '',
          metadata: {
            'msg_type': 'video',
            'status': IMBoyMessageStatus.myRevoked, // 31
          },
        );
        await _pump(tester, title: 'Reply', message: msg);

        // 撤回 block icon 渲染（覆盖了 video 分支）
        expect(find.byIcon(Icons.block), findsOneWidget);
        // video icon 不应出现
        expect(find.byIcon(Icons.videocam), findsNothing);
        expect(find.text(t.messageRevoked), findsOneWidget);
      },
    );
  });
}
