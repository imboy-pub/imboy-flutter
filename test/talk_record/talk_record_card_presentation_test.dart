import 'package:flutter/cupertino.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/modules/talk_record/presentation/share/talk_record_card_sender.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_preview_text.dart';
import 'package:imboy/store/api/talk_record_api.dart';
import 'package:imboy/store/model/message_model.dart';

import 'talk_record_results_test_helpers.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '1'});
    await StorageService.init();
    await StorageService.setMap(Keys.currentUser, {
      'uid': '1',
      'account': 'synthetic',
      'nickname': 'Synthetic',
      'avatar': '',
      'setting': <String, dynamic>{},
    });
    useZhCn();
  });
  test('payload is locator-only, ignoring raw URLs, summary and audio', () {
    final payload = talkRecordCardPayload(
      const TalkRecordShareCardData(
        cardType: 'talk_record_card',
        recordId: '1001',
        title: '面聊记录',
        raw: {
          'route': 'https://evil.invalid',
          'summary': 'secret',
          'audio': 'private',
        },
      ),
    );
    expect(payload.keys.toSet(), {'msg_type', 'record_id', 'content', 'title'});
    expect(payload.values, isNot(contains('secret')));
    expect(
      () => talkRecordCardPayload(
        const TalkRecordShareCardData(
          cardType: 'talk_record_card',
          recordId: '../1001',
        ),
      ),
      throwsFormatException,
    );
  });
  test(
    'type mapper and preview preserve controlled locator without title leak',
    () async {
      expect(MessageType.allTypes, contains('talk_record_card'));
      expect(
        MsgTypeEnumExtension.fromValue('talk_record_card'),
        MsgTypeEnum.talkRecordCard,
      );
      final model = MessageModel(
        'm',
        autoId: 0,
        type: 'C2C',
        status: 11,
        fromId: 1,
        toId: 2,
        payload: <String, dynamic>{'record_id': '1001', 'title': 'private'},
        isAuthor: 1,
        conversationUk3: 'C2C_1_2',
        msgType: 'talk_record_card',
      );
      final message = await model.toTypeMessage();
      expect(message, isA<CustomMessage>());
      expect(message.metadata?['record_id'], '1001');
      expect(
        messagePreviewText('talk_record_card', {'title': 'private'}),
        '[面聊记录]',
      );
    },
  );
  testWidgets('controlled alias redirects to authenticated-detail route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/talk-records/1001',
      routes: talkRecordRoutes(),
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      harnessScope(
        T21Harness(),
        child: CupertinoApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/talk_record/detail/1001',
    );
    expect(tester.takeException(), isNull);
  });
}
