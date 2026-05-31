import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/chat/widget/chat_message_list.dart';

/// ChatMessageList 渲染契约测试（TypeA 纯 StatelessWidget）
///
/// 用空 messages 列表，断言 ListView 结构与 reverse 属性，避免依赖
/// flutter_chat_core Message 实例与 message_type_registry 注册。
void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatMessageList(
            messages: const [],
            currentUserId: 'u1',
            onMessageLongPress: (_) {},
            onMessageDoubleTap: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('空消息列表 → 渲染 ListView 不崩溃', (tester) async {
    await pump(tester);
    expect(find.byType(ChatMessageList), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('列表为 reverse=true（新消息在底部）', (tester) async {
    await pump(tester);
    final listView = tester.widget<ListView>(find.byType(ListView));
    expect(listView.reverse, isTrue);
  });
}
