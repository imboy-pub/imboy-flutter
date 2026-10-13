import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';

// MC22 backFrom 壁探针：隔离验证 go_router push + GlassAppBar
// automaticallyImplyLeading 组合是否渲染 GlassBackButton。
void main() {
  testWidgets('push 后 GlassAppBar 应有返回键', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/chat/:peerId',
          pageBuilder: (_, state) => CupertinoPage(
            key: state.pageKey,
            child: Scaffold(
              appBar: GlassAppBar(
                titleWidget: const Text('chat'),
                automaticallyImplyLeading: true,
              ),
              body: const Text('chat body'),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.byType(GlassBackButton), findsNothing);
    unawaited(router.push('/chat/99?type=C2G'));
    await tester.pumpAndSettle();
    expect(find.text('chat body'), findsOneWidget);
    expect(
      find.byType(GlassBackButton),
      findsOneWidget,
      reason: 'router.push 后 Navigator.canPop 应为 true',
    );
  });
}
