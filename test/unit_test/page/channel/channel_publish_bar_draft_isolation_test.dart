import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_provider.dart';
import 'package:imboy/page/channel/widgets/channel_publish_bar.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/utils/chat_draft_keys.dart';

ChannelModel _channel(int id) => ChannelModel(
  id: id,
  name: 'synthetic channel',
  userRole: ChannelUserRole.creator,
  isSubscribed: true,
  creatorId: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

class _Publisher extends ChannelDetailNotifier {
  final result = Completer<bool>();
  @override
  ChannelDetailState build() => ChannelDetailState(
    channel: _channel(1001),
    isLoading: false,
    hasMore: false,
  );
  void switchChannel() => state = ChannelDetailState(
    channel: _channel(1002),
    isLoading: false,
    hasMore: false,
  );
  @override
  Future<bool> publishMessage({
    required String content,
    required String msgType,
    Map<String, dynamic>? payload,
  }) => result.future;
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    String uid, {
    _Publisher? publisher,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await StorageService.to.setString(Keys.currentUid, uid);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelDetailProvider.overrideWith(() => publisher ?? _Publisher()),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              bottomNavigationBar: ChannelPublishBar(
                channelId: '1001',
                focusNode: focus,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(const Key('composer_text_field')))
      .controller!
      .text;
  Future<void> enter(WidgetTester tester, String value) async {
    await tester.enterText(find.byKey(const Key('composer_text_field')), value);
    await tester.pumpAndSettle();
  }

  setUp(() async => StorageService.to.clear());
  tearDown(() async => StorageService.to.clear());

  testWidgets('same channel keeps separate account drafts', (tester) async {
    await mount(tester, 'A');
    await enter(tester, 'A draft');
    await mount(tester, 'B');
    expect(text(tester), isEmpty);
    await enter(tester, 'B draft');
    await mount(tester, 'A');
    expect(text(tester), 'A draft');
    await mount(tester, 'B');
    expect(text(tester), 'B draft');
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('legacy ownerless channel draft is ignored', (tester) async {
    await StorageService.to.setString('channel_draft_1001', 'ownerless');
    await mount(tester, 'A');
    expect(text(tester), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('missing account never persists channel text', (tester) async {
    await mount(tester, '');
    await enter(tester, 'anonymous');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(
      StorageService.to.getKeys().where((key) => key.contains('draft')),
      isEmpty,
    );
  });
  testWidgets('late publish clears original account and route only', (
    tester,
  ) async {
    final a = chatDraftKeys('A', 'channel-text', '1001')!.text;
    final b = chatDraftKeys('B', 'channel-text', '1002')!.text;
    await StorageService.to.setString(a, 'A draft');
    final publisher = _Publisher();
    await mount(tester, 'A', publisher: publisher);
    await enter(tester, 'sending A');
    await tester.tap(find.byTooltip(t.common.buttonSend));
    await tester.pump();
    await StorageService.to.setString(Keys.currentUid, 'B');
    await StorageService.to.setString(b, 'B draft');
    await StorageService.to.setString('channel_draft_1002', 'legacy B');
    publisher.switchChannel();
    await tester.pump();
    publisher.result.complete(true);
    await tester.pumpAndSettle();
    expect(StorageService.to.getString(a), isEmpty);
    expect(StorageService.to.getString(b), 'B draft');
    expect(StorageService.to.getString('channel_draft_1002'), 'legacy B');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
