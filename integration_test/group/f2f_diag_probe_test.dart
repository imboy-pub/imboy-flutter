// integration_test/group/f2f_diag_probe_test.dart
//
// 诊断探针（批次127，非验收用例）：定位「GF5 确认页在 join_group 事件
// 处理后消失」的根因层级。对照实验：
//   PROBE-2a 进确认页后纯推进虚拟时钟 8s（覆盖输码页 Timer 3s clearInput），
//           无任何事件——若确认页消失 ⇒ Timer/时钟型根因；
//   PROBE-1  手动 fire ChatExtendEvent('join_group')（S2C 同构 payload）
//           → 确认页消失 ⇒ 问题在确认页/事件监听代码；
//             不消失 ⇒ 问题在真实 WS 链路其他环节。
//
// 运行（同 face_to_face_acceptance 配方）：
//   flutter test integration_test/group/f2f_diag_probe_test.dart -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064 \
//     --dart-define=TEST_ALLOW_GROUP_WRITES=true

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/group/face_to_face/face_to_face_confirm_page.dart';
import 'package:imboy/page/group/face_to_face/face_to_face_page.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/store/model/people_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '111174215241304064',
);
const _peerUid = '111279969973569536';
const _code = '5163';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 10,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

void _dumpStack(WidgetTester tester, String tag) {
  final confirm = tester.any(find.byType(FaceToFaceConfirmPage));
  final f2f = tester.any(find.byType(FaceToFacePage));
  final two = tester.any(find.text('2 人即将进入群聊'));
  final one = tester.any(find.text('1 人即将进入群聊'));
  iPrint(
    '[$tag] confirm=$confirm f2fPage=$f2f 1人=$one 2人=$two '
    'uid=${UserRepoLocal.to.currentUid}',
  );
  if (!confirm) {
    try {
      final ctx = tester.element(find.byType(Navigator).first);
      final router = GoRouter.of(ctx);
      iPrint(
        '[$tag] location=${router.routeInformationProvider.value.uri} '
        'matches=${router.routerDelegate.currentConfiguration.matches.length}',
      );
    } catch (e) {
      iPrint('[$tag] 路由栈打印失败: $e');
    }
  }
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  for (var i = 0; i < 12; i++) {
    if (isOnMainShell(tester) ||
        tester.any(find.byKey(const Key('workspace-empty-create-entry')))) {
      break;
    }
    if (tester.any(find.byKey(const Key('login_submit_button')))) {
      await performLogin(
        tester,
        phone: FlowConfig.testPhone,
        password: FlowConfig.testPassword,
      );
    } else if (isOnWelcomePage(tester)) {
      await leaveWelcomePage(tester);
    }
    await _pump(tester, seconds: 6);
  }
  expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '载体须为 51730');
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PROBE join_group 事件 × 确认页存活对照', (tester) async {
    await _boot(tester);
    await TestPg.execute('DELETE FROM group_random_code WHERE user_id = @uid', {
      'uid': int.parse(_expectedUid),
    });

    GoRouter.of(
      tester.element(find.byType(Navigator).first),
    ).go('/group/face_to_face');
    await _waitFor(
      tester,
      () => tester.any(find.text('和身边的朋友输入同样的四个数字，进入同一个群聊')),
      seconds: 10,
    );

    // 键盘输码 → faceToFace → push 确认页
    for (final ch in _code.split('')) {
      await tester.tap(find.text(ch).last);
      await _pump(tester, seconds: 1);
    }
    expect(
      await _waitFor(tester, () => tester.any(find.text('进入该群')), seconds: 15),
      isTrue,
      reason: '前置：进确认页',
    );
    _dumpStack(tester, 'PROBE-0 进确认页');

    // gid（手动 fire 用）
    final gidRow = await TestPg.scalar(
      'SELECT group_id FROM group_random_code '
      'WHERE user_id = @uid AND code = @code '
      'ORDER BY created_at DESC LIMIT 1',
      {'uid': int.parse(_expectedUid), 'code': _code},
    );
    final gid = '$gidRow';
    iPrint('[PROBE] gid=$gid');

    // PROBE-2a：纯虚拟时钟 +8s（无任何事件），覆盖 Timer 3s clearInput
    await _pump(tester, seconds: 8);
    _dumpStack(tester, 'PROBE-2a 虚拟时钟+8s');

    // PROBE-1：手动 fire（S2C _handleGroupMemberJoin 同构 payload）
    AppEventBus.fire(
      ChatExtendEvent(
        type: 'join_group',
        payload: {
          'groupId': gid,
          'userId': _peerUid,
          'isFirst': true,
          'people': PeopleModel(
            id: int.parse(_peerUid),
            account: '51734',
            nickname: 'Batch123Peer',
            avatar: '',
          ),
        },
      ),
    );
    await _pump(tester, seconds: 3);
    _dumpStack(tester, 'PROBE-1 手动fire后');

    // 再补真实延迟 + pump（模拟 WS 异步链落地节奏）
    await Future<void>.delayed(const Duration(seconds: 2));
    await _pump(tester, seconds: 3);
    _dumpStack(tester, 'PROBE-1b 再等2s真实时间后');

    // PROBE-3：真实链路——B 账号 HTTP login + 同坐标 face2face 加入同码群，
    // 服务端向 A 推 group_member_join，观察真实事件链后确认页状态。
    // B 加入会触发 memberJoin→detail 404 链——这正是 GF5 真实环境的差异点。
    final lon = await TestPg.scalar(
      'SELECT ST_X(location) FROM group_random_code '
      'WHERE user_id = @uid AND code = @code '
      'ORDER BY created_at DESC LIMIT 1',
      {'uid': int.parse(_expectedUid), 'code': _code},
    );
    final lat = await TestPg.scalar(
      'SELECT ST_Y(location) FROM group_random_code '
      'WHERE user_id = @uid AND code = @code '
      'ORDER BY created_at DESC LIMIT 1',
      {'uid': int.parse(_expectedUid), 'code': _code},
    );
    final joined = await _httpFace2face(
      _code,
      '51798',
      'admin888c',
      'probepeerdevice1',
      ('$lon', '$lat'),
    );
    iPrint('[PROBE-3] B HTTP face2face joined=$joined');
    await Future<void>.delayed(const Duration(seconds: 4));
    await _pump(tester, seconds: 5);
    _dumpStack(tester, 'PROBE-3 真实B加入后');
    final cnt = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? '')
        .where((t) => t.contains('人即将进入群聊'))
        .toList();
    iPrint('[PROBE-3] 人数文案=$cnt');
  });
}

Future<bool> _httpFace2face(
  String code,
  String account,
  String password,
  String did,
  (String, String) lonLat,
) async {
  final client = HttpClient();
  try {
    final loginReq = await client.postUrl(
      Uri.parse('http://127.0.0.1:9801/api/v1/passport/login'),
    );
    loginReq.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    loginReq.write(
      'account=$account&pwd=$password&rsa_encrypt=0&type=account'
      '&did=$did&cos=macos',
    );
    final loginResp = await loginReq.close();
    final loginBody = await loginResp.transform(utf8.decoder).join();
    final loginJson = jsonDecode(loginBody) as Map<String, dynamic>;
    final token = loginJson['payload']?['token']?.toString() ?? '';
    if (token.isEmpty) {
      iPrint('[PROBE-3] B 登录失败: $loginBody');
      return false;
    }

    final req = await client.getUrl(
      Uri.parse(
        'http://127.0.0.1:9801/api/v1/group/face2face'
        '?code=$code&longitude=${lonLat.$1}&latitude=${lonLat.$2}',
      ),
    );
    req.headers.set('authorization', token);
    final resp = await req.close();
    final body = await resp.transform(utf8.decoder).join();
    iPrint('[PROBE-3] face2face resp=$body');
    return (jsonDecode(body) as Map<String, dynamic>)['code'] == 0;
  } finally {
    client.close();
  }
}
