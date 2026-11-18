import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/message_bubble_style.dart';
import 'package:imboy/theme/default/app_colors.dart';

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
    testWidgets('浅色发送方文本为品牌底白色', (tester) async {
      late TextStyle style;
      await withContext(tester, Brightness.light, (context) {
        style = MessageBubbleStyle.getMessageTextStyle(
          context: context,
          isSentByMe: true,
        );
      });
      // 发送方文本（浅色）：气泡主色之上的正文取 onPrimary（实现与
      // 暗色 sentMessageText 分支并存，见 message_bubble_style.dart）。
      expect(style.color, AppColors.onPrimary);
      // DSN-04 O1（属主裁决 2026-11-16）：聊天正文 17pt 合同。
      expect(style.fontSize, 17);
    });
    testWidgets('暗色发送方文本保留柔白，接收方跟随暗色文本', (tester) async {
      late TextStyle sent;
      late TextStyle received;
      await withContext(tester, Brightness.dark, (context) {
        sent = MessageBubbleStyle.getMessageTextStyle(
          context: context,
          isSentByMe: true,
        );
        received = MessageBubbleStyle.getMessageTextStyle(
          context: context,
          isSentByMe: false,
        );
      });
      expect(sent.color, AppColors.sentMessageText);
      expect(sent.color, isNot(Colors.white));
      expect(received.color, AppColors.getTextColor(Brightness.dark));
    });
  });
}
