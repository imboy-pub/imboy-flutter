/// Phase 1.1.g — Web Main Panel widget 测试
///
/// 覆盖：
/// - selection=null → 渲染 welcome
/// - 4 个 sealed selection 变体分别调用对应 builder
/// - builder 接收的 selection 对象与传入一致（参数透传）
/// - 切换 selection 后内容刷新
/// - 主题响应（surface 背景）
/// - sealed switch 穷尽性契约（编译期保证）
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_main_panel.dart';
import 'package:imboy/page/web_shell/web_shell_state.dart';

const _kWelcome = Center(
  key: ValueKey('welcome'),
  child: Text('WELCOME'),
);

Widget _chatBuilder(ChatSelection sel) => Center(
      key: const ValueKey('chat'),
      child: Text('CHAT:${sel.chatType}:${sel.peerId}'),
    );

Widget _contactBuilder(ContactSelection sel) => Center(
      key: const ValueKey('contact'),
      child: Text('CONTACT:${sel.uid}'),
    );

Widget _channelBuilder(ChannelSelection sel) => Center(
      key: const ValueKey('channel'),
      child: Text('CHANNEL:${sel.channelId}'),
    );

Widget _mineBuilder(MineSelection sel) => Center(
      key: const ValueKey('mine'),
      child: Text('MINE:${sel.section ?? "overview"}'),
    );

Future<void> _pumpPanel(
  WidgetTester tester, {
  required WebSelection? selection,
  Widget welcome = _kWelcome,
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: brightness,
        ),
      ),
      home: Scaffold(
        body: WebMainPanel(
          selection: selection,
          welcome: welcome,
          chatBuilder: _chatBuilder,
          contactBuilder: _contactBuilder,
          channelBuilder: _channelBuilder,
          mineBuilder: _mineBuilder,
        ),
      ),
    ),
  );
}

void main() {
  group('WebMainPanel — selection=null', () {
    testWidgets('渲染 welcome 内容', (tester) async {
      await _pumpPanel(tester, selection: null);
      expect(find.byKey(const ValueKey('welcome')), findsOneWidget);
      expect(find.text('WELCOME'), findsOneWidget);
    });

    testWidgets('其他 builder 不应被调用（无对应 widget 出现）', (tester) async {
      await _pumpPanel(tester, selection: null);
      expect(find.byKey(const ValueKey('chat')), findsNothing);
      expect(find.byKey(const ValueKey('contact')), findsNothing);
      expect(find.byKey(const ValueKey('channel')), findsNothing);
      expect(find.byKey(const ValueKey('mine')), findsNothing);
    });

    testWidgets('自定义 welcome widget 可注入', (tester) async {
      await _pumpPanel(
        tester,
        selection: null,
        welcome: const Center(
          key: ValueKey('custom-welcome'),
          child: Text('CUSTOM'),
        ),
      );
      expect(find.byKey(const ValueKey('custom-welcome')), findsOneWidget);
      expect(find.text('CUSTOM'), findsOneWidget);
    });
  });

  group('WebMainPanel — ChatSelection 分发', () {
    testWidgets('渲染 chatBuilder 内容', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );
      expect(find.byKey(const ValueKey('chat')), findsOneWidget);
      expect(find.text('CHAT:C2C:p1'), findsOneWidget);
    });

    testWidgets('chatBuilder 接收的 selection 对象透传 (peerId+chatType)',
        (tester) async {
      await _pumpPanel(
        tester,
        selection: const ChatSelection(peerId: 'group1', chatType: 'C2G'),
      );
      expect(find.text('CHAT:C2G:group1'), findsOneWidget);
    });

    testWidgets('其他 builder 不应被调用', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );
      expect(find.byKey(const ValueKey('welcome')), findsNothing);
      expect(find.byKey(const ValueKey('contact')), findsNothing);
      expect(find.byKey(const ValueKey('channel')), findsNothing);
      expect(find.byKey(const ValueKey('mine')), findsNothing);
    });
  });

  group('WebMainPanel — ContactSelection 分发', () {
    testWidgets('渲染 contactBuilder 内容 + uid 透传', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ContactSelection(uid: 'user_42'),
      );
      expect(find.byKey(const ValueKey('contact')), findsOneWidget);
      expect(find.text('CONTACT:user_42'), findsOneWidget);
    });

    testWidgets('其他 builder 不应被调用', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ContactSelection(uid: 'u1'),
      );
      expect(find.byKey(const ValueKey('welcome')), findsNothing);
      expect(find.byKey(const ValueKey('chat')), findsNothing);
      expect(find.byKey(const ValueKey('channel')), findsNothing);
      expect(find.byKey(const ValueKey('mine')), findsNothing);
    });
  });

  group('WebMainPanel — ChannelSelection 分发', () {
    testWidgets('渲染 channelBuilder 内容 + channelId 透传', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ChannelSelection(channelId: 'ch_99'),
      );
      expect(find.byKey(const ValueKey('channel')), findsOneWidget);
      expect(find.text('CHANNEL:ch_99'), findsOneWidget);
    });

    testWidgets('其他 builder 不应被调用', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ChannelSelection(channelId: 'ch1'),
      );
      expect(find.byKey(const ValueKey('welcome')), findsNothing);
      expect(find.byKey(const ValueKey('chat')), findsNothing);
      expect(find.byKey(const ValueKey('contact')), findsNothing);
      expect(find.byKey(const ValueKey('mine')), findsNothing);
    });
  });

  group('WebMainPanel — MineSelection 分发', () {
    testWidgets('section=null → 渲染 overview', (tester) async {
      await _pumpPanel(
        tester,
        selection: const MineSelection(),
      );
      expect(find.byKey(const ValueKey('mine')), findsOneWidget);
      expect(find.text('MINE:overview'), findsOneWidget);
    });

    testWidgets('section 非 null → 透传 key', (tester) async {
      await _pumpPanel(
        tester,
        selection: const MineSelection(section: 'privacy'),
      );
      expect(find.text('MINE:privacy'), findsOneWidget);
    });

    testWidgets('其他 builder 不应被调用', (tester) async {
      await _pumpPanel(
        tester,
        selection: const MineSelection(),
      );
      expect(find.byKey(const ValueKey('welcome')), findsNothing);
      expect(find.byKey(const ValueKey('chat')), findsNothing);
      expect(find.byKey(const ValueKey('contact')), findsNothing);
      expect(find.byKey(const ValueKey('channel')), findsNothing);
    });
  });

  group('WebMainPanel — 切换 selection 刷新', () {
    testWidgets('null → ContactSelection → ChatSelection 内容跟随变化',
        (tester) async {
      // step 1: null → welcome
      await _pumpPanel(tester, selection: null);
      expect(find.byKey(const ValueKey('welcome')), findsOneWidget);

      // step 2: ContactSelection → 调 contactBuilder
      await _pumpPanel(
        tester,
        selection: const ContactSelection(uid: 'u1'),
      );
      expect(find.byKey(const ValueKey('contact')), findsOneWidget);
      expect(find.text('CONTACT:u1'), findsOneWidget);

      // step 3: ChatSelection → 调 chatBuilder
      await _pumpPanel(
        tester,
        selection: const ChatSelection(peerId: 'p1', chatType: 'C2C'),
      );
      expect(find.byKey(const ValueKey('chat')), findsOneWidget);
      expect(find.text('CHAT:C2C:p1'), findsOneWidget);
    });
  });

  group('WebMainPanel — 主题响应', () {
    testWidgets('背景用 ColorScheme.surface', (tester) async {
      await _pumpPanel(tester, selection: null);
      final BuildContext ctx = tester.element(find.byType(WebMainPanel));
      final cs = Theme.of(ctx).colorScheme;
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(WebMainPanel),
          matching: find.byType(Container),
        ).first,
      );
      expect(container.color, cs.surface);
    });

    testWidgets('dark theme 不抛异常', (tester) async {
      await _pumpPanel(
        tester,
        selection: const ContactSelection(uid: 'u1'),
        brightness: Brightness.dark,
      );
      expect(find.byKey(const ValueKey('contact')), findsOneWidget);
    });
  });
}
