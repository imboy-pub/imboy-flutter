import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/message_bubble_style.dart';

/// MessageBubbleStyle 纯样式逻辑契约测试（TypeB）
///
/// 通过 Builder 提供 BuildContext，断言静态样式方法的关键输出。
void main() {
  /// 在给定 brightness 下执行回调，回调内可访问 BuildContext。
  Future<void> withContext(
    WidgetTester tester,
    Brightness brightness,
    void Function(BuildContext context) body,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Builder(
          builder: (context) {
            body(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  group('MessageBubbleStyle.getBubbleDecoration', () {
    testWidgets('发送方与接收方气泡颜色不同（双蓝策略）', (tester) async {
      late BoxDecoration sent;
      late BoxDecoration received;
      await withContext(tester, Brightness.light, (context) {
        sent = MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: true,
        );
        received = MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: false,
        );
      });
      expect(sent.color, isNot(equals(received.color)));
      expect(sent.borderRadius, isNotNull);
    });

    testWidgets('isHighlighted=true → 使用半透明高亮色', (tester) async {
      late BoxDecoration normal;
      late BoxDecoration highlighted;
      await withContext(tester, Brightness.light, (context) {
        normal = MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: false,
          isHighlighted: false,
        );
        highlighted = MessageBubbleStyle.getBubbleDecoration(
          context: context,
          isSentByMe: false,
          isHighlighted: true,
        );
      });
      expect(highlighted.color, isNot(equals(normal.color)));
    });
  });

  group('MessageBubbleStyle.getStatusIconColor', () {
    testWidgets('接收方消息 → 状态图标透明（不显示）', (tester) async {
      late Color color;
      await withContext(tester, Brightness.light, (context) {
        color = MessageBubbleStyle.getStatusIconColor(
          context: context,
          isSentByMe: false,
        );
      });
      expect(color, Colors.transparent);
    });

    testWidgets('发送方已读 → 已读语义色（非透明）', (tester) async {
      late Color color;
      await withContext(tester, Brightness.light, (context) {
        color = MessageBubbleStyle.getStatusIconColor(
          context: context,
          isSentByMe: true,
          status: MessageStatus.read,
        );
      });
      expect(color, isNot(Colors.transparent));
    });
  });

  group('MessageBubbleStyle.getMessageTextStyle', () {
    testWidgets('发送方文本为白色', (tester) async {
      late TextStyle style;
      await withContext(tester, Brightness.light, (context) {
        style = MessageBubbleStyle.getMessageTextStyle(
          context: context,
          isSentByMe: true,
        );
      });
      expect(style.color, Colors.white);
      expect(style.fontSize, 16);
    });
  });
}
