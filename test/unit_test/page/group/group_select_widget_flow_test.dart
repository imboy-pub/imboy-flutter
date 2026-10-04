import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_select/group_select_page.dart';
import 'package:imboy/page/group/group_select/group_select_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';

/// 群选择页 widget 流程测试（group 域 F00 group_select_page:004）。
///
/// 覆盖（对应 fn:group:group_select_page 判定行；校准注记登记用）：
///   流程A 无名群渲染兜底 + 跳转传 resolvedTitle（:004/:002）：
///         列表行用 displayTitle（缺名兜「未命名」），但跳转 extra 的
///         peerTitle 刻意传 resolvedTitle（不兜底）——无名群传空串，
///         让聊天页继续走群详情/成员名查找链。
///
/// 数据隔离：groupSelectProvider 由 Spy 覆写（预置两条 ConversationModel，
/// loadData 不触 API）；头像用非空 URL 绕开 SmartGroupAvatar 的 loader
/// 通道（loader 走 service→API，FakeAsync 下无法落定）。
/// 路由：GoRouter 测试壳，/chat/:id 为捕获页记录 extra。
/// 运行：flutter test test/unit_test/page/group/group_select_widget_flow_test.dart

class SpyGroupSelectNotifier extends GroupSelectNotifier {
  SpyGroupSelectNotifier(this.seeded);

  final List<ConversationModel> seeded;

  @override
  GroupSelectState build() => GroupSelectState(items: seeded);

  @override
  Future<void> loadData() async {
    // 预置数据已随 build 注入，不再触 service/API
  }
}

ConversationModel _conv(int peerId, String title) => ConversationModel(
  id: peerId,
  peerId: peerId,
  avatar: 'https://example.invalid/a$peerId.png',
  title: title,
  subtitle: '',
  type: 'C2G',
  msgType: 'text',
  unreadNum: 0,
);

class _CapturePage extends StatelessWidget {
  const _CapturePage();

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra;
    // ignore: avoid_print
    print('[capture] extra=$extra');
    return Scaffold(
      body: Text('captured:${extra is Map ? extra['peerTitle'] : 'NO-EXTRA'}'),
    );
  }
}

Future<void> _openPage(
  WidgetTester tester,
  List<ConversationModel> items,
) async {
  final router = GoRouter(
    initialLocation: '/group_select',
    routes: [
      GoRoute(
        path: '/group_select',
        builder: (_, _) => const GroupSelectPage(),
      ),
      GoRoute(path: '/chat/:id', builder: (_, _) => const _CapturePage()),
    ],
  );

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          groupSelectProvider.overrideWith(() => SpyGroupSelectNotifier(items)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('流程A 无名群 displayTitle 兜底渲染，跳转传 resolvedTitle 不兜底', (
    tester,
  ) async {
    await _openPage(tester, [_conv(8101, '项目群'), _conv(8102, '')]);

    // 列表行渲染 displayTitle：有名显示群名，无名兜「未命名」
    expect(find.text('项目群'), findsOneWidget);
    expect(
      find.text(t.main.unnamed),
      findsOneWidget,
      reason: '无名群行应兜底渲染「未命名」（displayTitle）',
    );

    // 点无名群行：extra.peerTitle 必须是空串（resolvedTitle），不是「未命名」
    await tester.tap(find.text(t.main.unnamed));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('captured:'),
      findsOneWidget,
      reason:
          '跳转 extra.peerTitle 应为 resolvedTitle 空串（不兜底），'
          '保住聊天页的群详情/成员名查找链',
    );
  });

  testWidgets('流程B 有名群跳转传真实群名', (tester) async {
    await _openPage(tester, [_conv(8101, '项目群'), _conv(8102, '')]);

    await tester.tap(find.text('项目群'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.text('captured:项目群'),
      findsOneWidget,
      reason: '有名群跳转 extra.peerTitle 应为群名',
    );
  });
}
