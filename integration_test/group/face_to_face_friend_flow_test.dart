// Owned fixture: backend test/api/face_to_face_http_tests:setup/0, loopback only.
// flutter test integration_test/group/face_to_face_friend_flow_test.dart -d <physical-device>
//   --flavor gzCustomer --no-uninstall --dart-define-from-file=<private-fixture-json>
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv, serviceContainer;
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/apply_friend/apply_friend_page.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_confirm_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_provider.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';

const _token = String.fromEnvironment('TEST_TOKEN');
const _peerToken = String.fromEnvironment('TEST_PEER_TOKEN');
const _uid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peer = String.fromEnvironment('TEST_PEER_UID');
const _base = String.fromEnvironment('API_BASE_URL_OVERRIDE');

Future<Map<String, dynamic>> _peerRequest(
  String method,
  String path, [
  Map<String, dynamic>? body,
]) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse('$_base$path'));
    request.headers.set('authorization', 'Bearer $_peerToken');
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final response = await request.close();
    expect(response.statusCode, 200);
    final data = jsonDecode(
      await utf8.decoder.bind(response).join(),
    ) as Map<String, dynamic>;
    expect(data['code'], 0, reason: '${data['msg']}');
    return data;
  } finally {
    client.close(force: true);
  }
}

Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 120 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('面对面真机接口与好友申请闭环（合成定位，不验证GPS权限）', (tester) async {
    expect(const String.fromEnvironment('TEST_ALLOW_GROUP_WRITES'), 'true');
    expect([_token, _peerToken, _uid, _peer], everyElement(isNotEmpty));
    expect(Uri.parse(_base).host, '127.0.0.1');
    currentEnv = 'local';
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _uid);
    await StorageService.setMap(Keys.currentUser, {
      'id': _uid,
      'account': 'f2f-fixture',
      'nickname': '面对面验证',
      'setting': <String, dynamic>{},
    });
    await SecureTokenStorageService.saveToken(_token);
    serviceContainer.put(app_http.HttpClient());
    addTearDown(serviceContainer.clear);
    expect((await SqliteService.to.db)?.isOpen, isTrue);
    addTearDown(SqliteService.to.close);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const FaceToFacePage()),
        GoRoute(
          path: '/group/face_to_face_confirm',
          builder: (_, state) {
            final extra = state.extra! as Map<String, dynamic>;
            return FaceToFaceConfirmPage(
              gid: extra['gid'] as String,
              code: extra['code'] as String,
              memberList: extra['memberList'] as List<PeopleModel>,
            );
          },
        ),
        GoRoute(
          path: '/people_info/:id',
          builder: (_, state) => PeopleInfoPage(
            id: state.pathParameters['id']!,
            scene: 'group_member',
          ),
        ),
        // 本专项验证群资料落库与正式聊天路由参数；聊天消息由双端专项验收。
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              Scaffold(body: Text('chat:${state.pathParameters['id']}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          faceToFaceLocationProvider.overrideWithValue(
            () async => const ImboyLocation(latitude: 39.9, longitude: 116.4),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            builder: AppLoading.init(),
          ),
        ),
      ),
    );
    await _waitFor(tester, find.byType(NumericKeypad));
    for (final digit in ['0', '1', '2', '3']) {
      await tester.tap(
        find.descendant(
          of: find.byType(NumericKeypad),
          matching: find.text(digit),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _waitFor(tester, find.byType(FaceToFaceConfirmPage));
    final page = tester.widget<FaceToFaceConfirmPage>(
      find.byType(FaceToFaceConfirmPage),
    );
    final gid = page.gid;
    expect(page.code, '0123');
    final joined = await _peerRequest(
      'GET',
      '/api/v1/group/face2face?code=0123&longitude=116.4001&latitude=39.9',
    );
    expect('${(joined['payload'] as Map)['gid']}', gid);
    await _waitFor(tester, find.text(t.common.f2fEnteringGroup(count: 2)));
    final confirmState = tester.state<FaceToFaceConfirmPageState>(
      find.byType(FaceToFaceConfirmPage),
    );
    final name = confirmState.memberList
        .singleWhere((person) => person.id == _peer)
        .nickname;
    expect(name, isNotEmpty);
    await tester.tap(find.text(name));
    await _waitFor(tester, find.byType(PeopleInfoPage));
    await _waitFor(tester, find.text(t.common.addToContacts));
    await tester.ensureVisible(find.text(t.common.addToContacts));
    await tester.tap(find.text(t.common.addToContacts));
    await _waitFor(tester, find.byType(ApplyFriendPage));
    final submit = find.widgetWithText(CupertinoButton, t.common.buttonSend);
    // 按页面已有文案定位提交按钮，避免复制业务提交逻辑。
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await _waitFor(tester, find.byType(FaceToFaceConfirmPage));
    await _peerRequest('POST', '/api/v1/friend/confirm', {
      'from': _uid,
      'to': _peer,
      'payload': {
        'from': {'source': 'group_member'},
        'to': <String, dynamic>{},
      },
    });
    final friends = await _peerRequest('GET', '/api/v1/friend/list');
    expect('${friends['payload']}', contains(_uid));
    await tester.tap(find.text(t.group.enterTheGroup));
    await _waitFor(tester, find.text('chat:$gid'));
    expect((await GroupRepo().findById(gid))?.groupId, gid);
    expect(Env().apiBaseUrl, _base);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
