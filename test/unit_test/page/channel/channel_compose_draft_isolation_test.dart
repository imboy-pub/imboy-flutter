import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_compose_page.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/utils/chat_draft_keys.dart';
import 'package:imboy/store/model/channel_model.dart';

class _PendingPublisher extends ChannelDetailNotifier {
  final result = Completer<bool>();
  int calls = 0;
  void switchChannel() => state = ChannelDetailState(
    channel: ChannelModel(
      id: 995502,
      name: 'other',
      creatorId: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
  @override
  ChannelDetailState build() => ChannelDetailState(
    channel: ChannelModel(
      id: 995501,
      name: 'test',
      creatorId: 1,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  );
  @override
  Future<bool> publishMessage({
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
    String? expectedChannelId,
  }) {
    calls++;
    return result.future;
  }
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    String uid, {
    _PendingPublisher? publisher,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await StorageService.to.setString(Keys.currentUid, uid);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const Scaffold()),
        GoRoute(
          path: '/compose',
          builder: (_, _) => const ChannelComposePage(channelId: '995501'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (publisher != null)
            channelDetailProvider.overrideWith(() => publisher),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            builder: AppLoading.init(),
          ),
        ),
      ),
    );
    router.push<void>('/compose');
    await tester.pumpAndSettle();
  }

  Future<void> enter(WidgetTester tester, String title, String body) async {
    await tester.enterText(find.byType(TextField).first, title);
    await tester.enterText(find.byType(TextField).last, body);
    await tester.pump();
  }

  List<String> text(WidgetTester tester) => tester
      .widgetList<TextField>(find.byType(TextField))
      .map((field) => field.controller!.text)
      .toList();

  setUp(() async => StorageService.to.clear());
  tearDown(() async => StorageService.to.clear());

  testWidgets('same channel preserves separate account titles and bodies', (
    tester,
  ) async {
    await mount(tester, '1001');
    await enter(tester, 'A title', 'A body');
    await mount(tester, '1002');
    expect(text(tester), ['', '']);
    await enter(tester, 'B title', 'B body');
    await mount(tester, '1001');
    expect(text(tester), ['A title', 'A body']);
    await mount(tester, '1002');
    expect(text(tester), ['B title', 'B body']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('legacy ownerless article is not restored', (tester) async {
    await StorageService.to.setString(
      'channel_compose_draft_995501',
      'ownerless',
    );
    await mount(tester, '1001');
    expect(text(tester), ['', '']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('missing UID never persists article text', (tester) async {
    await mount(tester, '');
    await enter(tester, 'anonymous title', 'anonymous body');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      StorageService.to.getKeys().where((key) => key.contains('draft')),
      isEmpty,
    );
  });

  testWidgets(
    'dispose after account switch persists only for original account',
    (tester) async {
      await mount(tester, '1001');
      await enter(tester, 'pending A title', 'pending A body');
      await StorageService.to.setString(Keys.currentUid, '1002');
      await mount(tester, '1002');
      expect(text(tester), ['', '']);
      await mount(tester, '1001');
      expect(text(tester), ['pending A title', 'pending A body']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('late publish clears only original account article', (
    tester,
  ) async {
    final a = chatDraftKeys('1001', 'channel-compose', '995501')!.text;
    final b = chatDraftKeys('1002', 'channel-compose', '995501')!.text;
    await StorageService.to.setString(a, '{"title":"A title","body":"A body"}');
    final publisher = _PendingPublisher();
    await mount(tester, '1001', publisher: publisher);
    await enter(tester, 'A title', 'A body');
    await tester.tap(find.widgetWithText(CupertinoButton, t.channel.publish));
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, '1002');
    await StorageService.to.setString(b, '{"title":"B title","body":"B body"}');
    publisher.result.complete(true);
    await tester.pumpAndSettle();
    expect(StorageService.to.getString(a), isEmpty);
    expect(StorageService.to.getString(b), contains('B body'));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('共享详情切到其他频道时图文发布入口不可用', (tester) async {
    final publisher = _PendingPublisher();
    await mount(tester, '1001', publisher: publisher);
    await enter(tester, 'title', 'body');
    publisher.switchChannel();
    await tester.pump();
    final button = tester.widget<CupertinoButton>(
      find.widgetWithText(CupertinoButton, t.channel.publish),
    );
    expect(button.onPressed, isNull);
    expect(text(tester), ['title', 'body']);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('切换账号后相同频道的旧图文草稿不会发出', (tester) async {
    final publisher = _PendingPublisher();
    await mount(tester, '1001', publisher: publisher);
    await enter(tester, 'title', 'body');
    await StorageService.to.setString(Keys.currentUid, '1002');
    await tester.tap(find.widgetWithText(CupertinoButton, t.channel.publish));
    await tester.pump();
    expect(publisher.calls, 0);
    expect(text(tester), ['title', 'body']);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
