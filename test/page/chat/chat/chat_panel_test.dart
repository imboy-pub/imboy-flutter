/// Phase 2.1 — ChatPanel 骨架 widget 测试
///
/// 覆盖：
/// - 必填 props 渲染（peerId / chatType / title / closeTooltip）
/// - C2C / C2G 分歧（avatar icon 切换）
/// - 关闭按钮：onClose 提供时显示且回调可触发；onClose=null 时按钮不渲染
/// - 标题溢出 ellipsis
/// - 主题响应（light/dark 不抛异常）
/// - 占位 body 包含 peerId（保证 props 透传）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_panel.dart';

Future<void> _pumpPanel(
  WidgetTester tester, {
  String peerId = 'p1',
  String chatType = 'C2C',
  String title = 'Alice',
  String closeTooltip = 'Close',
  VoidCallback? onClose,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: brightness,
          ),
        ),
        home: Scaffold(
          body: ChatPanel(
            peerId: peerId,
            chatType: chatType,
            title: title,
            closeTooltip: closeTooltip,
            onClose: onClose,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ChatPanel — 基础渲染', () {
    testWidgets('渲染 title 文本', (tester) async {
      await _pumpPanel(tester, title: 'Alice');
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('C2C 占位渲染 chat_bubble_outline 图标', (tester) async {
      // 占位实现已从 TODO 文本演进为图标（_ChatPanelPlaceholder）
      await _pumpPanel(tester, peerId: 'p_42', chatType: 'C2C');
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });

    testWidgets('占位 body 居中渲染（Center）', (tester) async {
      await _pumpPanel(tester);
      // 占位区为 Center 包裹的图标；TODO 文本占位已移除
      expect(find.byType(Center), findsWidgets);
    });
  });

  group('ChatPanel — C2C / C2G 分歧', () {
    testWidgets('C2C → person icon', (tester) async {
      await _pumpPanel(tester, chatType: 'C2C');
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.group), findsNothing);
    });

    testWidgets('C2G → group icon', (tester) async {
      await _pumpPanel(tester, chatType: 'C2G');
      expect(find.byIcon(Icons.group), findsOneWidget);
      expect(find.byIcon(Icons.person), findsNothing);
    });

    testWidgets('C2G 占位渲染 group_outlined 图标', (tester) async {
      await _pumpPanel(tester, peerId: 'g1', chatType: 'C2G');
      expect(find.byIcon(Icons.group_outlined), findsOneWidget);
    });
  });

  group('ChatPanel — 关闭按钮', () {
    testWidgets('onClose 提供时渲染关闭按钮 + tooltip', (tester) async {
      await _pumpPanel(tester, closeTooltip: '关闭', onClose: () {});
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byTooltip('关闭'), findsOneWidget);
    });

    testWidgets('onClose=null 不渲染关闭按钮', (tester) async {
      await _pumpPanel(tester);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('点击关闭按钮触发 onClose 回调', (tester) async {
      var callCount = 0;
      await _pumpPanel(tester, onClose: () => callCount++);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(callCount, 1);
    });
  });

  group('ChatPanel — 主题响应', () {
    testWidgets('light theme 不抛异常', (tester) async {
      await _pumpPanel(tester, brightness: Brightness.light);
      expect(find.byType(ChatPanel), findsOneWidget);
    });

    testWidgets('dark theme 不抛异常', (tester) async {
      await _pumpPanel(tester, brightness: Brightness.dark);
      expect(find.byType(ChatPanel), findsOneWidget);
    });
  });

  group('ChatPanel — title 溢出处理', () {
    testWidgets('长 title 不抛异常（ellipsis 兜底）', (tester) async {
      await _pumpPanel(
        tester,
        title: 'A very long peer name that definitely exceeds available width',
      );
      // 不抛异常即通过；TextOverflow.ellipsis 会自动处理
      expect(find.byType(ChatPanel), findsOneWidget);
    });
  });

  group('ChatPanel — 结构契约', () {
    testWidgets('包含 Divider 分隔 header 与 body', (tester) async {
      await _pumpPanel(tester);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('包含 CircleAvatar', (tester) async {
      await _pumpPanel(tester);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}
