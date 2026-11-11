import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';

/// W3-I / BND-04：chat_history_bundle 气泡渲染。
///
/// 断言：title（含缺省回退）、条数文案、类型小图标、
/// `history_bundle_bubble_<id>` key、点击经 `/chat/history_bundle`
/// 路由把 bundle 快照 Map 作为 extra 传给详情页。
void main() {
  Map<String, dynamic> bundlePayload({String? title}) => <String, dynamic>{
    'msg_type': 'chat_history_bundle',
    // null-aware element：title 为 null 时不写入该键
    'title': ?title,
    'bundle_version': 1,
    'entries': [
      {
        'msg_type': 'text',
        'sender_name': '张三',
        'payload': {'text': '第一条'},
      },
      {
        'msg_type': 'image',
        'sender_name': '李四',
        'payload': {'name': 'a.png'},
      },
      {
        'msg_type': 'file',
        'sender_name': '王五',
        'payload': {'name': 'b.pdf'},
      },
    ],
  };

  /// 经真实插件 build（与 CustomMessageBuilder 同入口），Builder 提供真实
  /// BuildContext（气泡渲染读 Theme）。
  Widget bubbleHost(String id, Map<String, dynamic> meta) => Scaffold(
    body: Builder(
      builder: (context) => const ChatHistoryBundleMessageTypePlugin().build(
        CustomMessage(id: id, authorId: 'peer', metadata: meta),
        MessageRenderContext(
          context: context,
          type: 'C2C',
          user: const User(id: 'me'),
          isSentByMe: false,
          bubbleWrapper: (child) => child,
        ),
      ),
    ),
  );

  GoRouter buildRouter(
    Widget home, {
    void Function(Map<String, dynamic>?)? onExtra,
  }) {
    return GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => home),
        GoRoute(
          path: kHistoryBundleDetailRoute,
          name: 'chat_history_bundle_detail',
          builder: (context, state) {
            onExtra?.call(state.extra as Map<String, dynamic>?);
            return const Scaffold(body: Text('详情页'));
          },
        ),
      ],
    );
  }

  testWidgets('气泡展示 title、条数与类型小图标，key 含消息 id', (tester) async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    final router = buildRouter(bubbleHost('b1', bundlePayload(title: '产品群')));
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('产品群'), findsOneWidget);
    expect(find.text('[聊天记录] 3 条'), findsOneWidget);
    final bubbleFinder = find.byKey(const Key('history_bundle_bubble_b1'));
    expect(bubbleFinder, findsOneWidget);
    // text/image/file 三类 entry → 三个去重小图标
    expect(
      find.descendant(
        of: bubbleFinder,
        matching: find.byIcon(CupertinoIcons.text_alignleft),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bubbleFinder,
        matching: find.byIcon(CupertinoIcons.photo),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: bubbleFinder,
        matching: find.byIcon(CupertinoIcons.doc),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('title 缺省回退「聊天记录」，entries 畸形按 0 条展示', (tester) async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    final router = buildRouter(
      bubbleHost('b2', <String, dynamic>{'msg_type': 'chat_history_bundle'}),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('聊天记录'), findsOneWidget);
    expect(find.text('[聊天记录] 0 条'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });

  testWidgets('点击气泡 push 详情路由，extra 携带 bundle 快照 Map', (tester) async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
    Map<String, dynamic>? pushedExtra;
    final payload = bundlePayload(title: '产品群');
    final router = buildRouter(
      bubbleHost('b3', payload),
      onExtra: (extra) => pushedExtra = extra,
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history_bundle_bubble_b3')));
    await tester.pumpAndSettle();

    expect(find.text('详情页'), findsOneWidget);
    expect(pushedExtra, isNotNull);
    // 快照原样透传（含 entries），详情页据此渲染、不回查原会话
    expect(pushedExtra!['title'], '产品群');
    expect(pushedExtra!['entries'], isA<List<dynamic>>());
    expect((pushedExtra!['entries'] as List).length, 3);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
  });
}
