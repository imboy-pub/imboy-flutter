/// 频道 ⋮ 溢出菜单「频道二维码」直达项（个人频道 standalone 与企业频道
/// embedded 共用同一菜单）：管理员与订阅者两种视图都应有该项，点击直接
/// 落到 /qrcode/channel 并携带与频道链接页同契约的 extra（id 为字符串）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_overflow_menu.dart';
import 'package:imboy/store/model/channel_model.dart';

ChannelModel _channel(ChannelUserRole role) => ChannelModel(
  id: 1001,
  name: '合成频道',
  avatar: 'synthetic_avatar.png',
  creatorId: 1,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  userRole: role,
  isSubscribed: role != ChannelUserRole.none,
);

Future<GoRouter> _pump(WidgetTester tester, ChannelModel channel) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          appBar: AppBar(actions: [ChannelOverflowMenu(channel: channel)]),
          body: const SizedBox.shrink(),
        ),
      ),
      GoRoute(
        path: '/qrcode/channel',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Scaffold(
            body: Text(
              'qr:${extra?['id']}:${extra?['id'].runtimeType}:${extra?['name']}',
            ),
          );
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  return router;
}

void main() {
  setUpAll(() async {
    await LocaleSettings.setLocale(AppLocale.zhCn);
  });

  for (final (label, role) in [
    ('管理员视图', ChannelUserRole.admin),
    ('订阅者视图', ChannelUserRole.subscriber),
  ]) {
    testWidgets('$label：⋮ 菜单含「频道二维码」且直达二维码页', (tester) async {
      await _pump(tester, _channel(role));
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis_vertical));
      await tester.pumpAndSettle();

      final item = find.text(t.channel.qrcode);
      expect(item, findsOneWidget);
      // 分享项仍在（二维码是直达补充，不替代分享面板）。
      expect(find.text(t.channel.share), findsOneWidget);

      await tester.tap(item);
      await tester.pumpAndSettle();
      // id 以字符串传递（与频道链接页同契约，二维码页 toString 兼容）。
      expect(find.text('qr:1001:String:合成频道'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
