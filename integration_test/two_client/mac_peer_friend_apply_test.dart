// integration_test/two_client/mac_peer_friend_apply_test.dart
//
// 双端测试 · macOS 对端侧：以 QA 对端账号登录，向 Android 真机账号发起好友申请。
// Android 侧用 adb 驱动验收 new_friend / confirm_new_friend 等阻塞用例。
//
// 好友申请只发往显式指定的自管 QA uid（PEER_UID 必填、无默认值），
// 不会打扰任何第三方账号；申请可被对方拒绝/删除，非不可逆。
//
// 运行（macOS 桌面）：
//   flutter test integration_test/two_client/mac_peer_friend_apply_test.dart -d macos \
//     --dart-define=APP_ENV=pro \
//     --dart-define=API_BASE_URL=https://pro.imboy.pub \
//     --dart-define=TEST_PHONE=<对端账号> \
//     --dart-define=TEST_PASSWORD=<对端密码> \
//     --dart-define=PEER_UID=<Android真机账号uid> \
//     --dart-define=TEST_ALLOW_FRIEND_APPLY=true

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _peerUid = String.fromEnvironment('PEER_UID', defaultValue: '');

const _friendApplyFlag = String.fromEnvironment(
  'TEST_ALLOW_FRIEND_APPLY',
  defaultValue: 'false',
);

final bool _allowFriendApply =
    _friendApplyFlag == 'true' || _friendApplyFlag == 'True';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('双端 · macOS 对端发起好友申请', () {
    testWidgets(
      '对端账号登录后向 PEER_UID 发起好友申请',
      (tester) async {
        if (!_allowFriendApply) {
          markTestSkipped('需显式 TEST_ALLOW_FRIEND_APPLY=true');
          return;
        }
        if (_peerUid.isEmpty) {
          markTestSkipped('需显式 PEER_UID=<对端uid>，禁止默认写入');
          return;
        }

        await ensureAppLaunched(tester, maxSeconds: 5);
        if (!await checkPreconditions(tester)) return;

        final loggedIn = await autoLoginOrSkip(tester);
        if (!loggedIn) return;
        if (!await waitForMainShell(tester)) {
          fail('对端账号登录成功但主 Shell 未挂载');
        }
        await takeScreenshot(tester, 'mac_peer_01_main_shell');

        final me = UserRepoLocal.to.current;
        flowLog(
          '对端已登录: uid=${UserRepoLocal.to.currentUid} '
          'nickname=${me.nickname}',
        );

        // 与 apply_friend_page.dart 保持同构的 payload（from/to 结构）。
        // source=search 不触发 allow_add_by_phone/qrcode 隐私开关校验。
        final payload = <String, dynamic>{
          'from': {
            'source': 'search',
            'msg': 'qa 双端自动化好友申请',
            'remark': '',
            'account': me.account,
            'nickname': me.nickname,
            'avatar': me.avatar,
            'sign': me.sign,
            'gender': me.gender,
            'region': me.region,
            'role': '',
            'donotlookhim': false,
            'donotlethimlook': false,
            'tag': '',
          },
          'to': <String, dynamic>{},
        };
        final body = <String, dynamic>{
          'to': _peerUid,
          'payload': json.encode(payload),
          'created_at': DateTimeHelper.millisecond(),
        };

        final resp = await HttpClient.client.post(
          '${Env().apiBaseUrl}${API.addFriend}',
          data: body,
          options: Options(contentType: 'application/x-www-form-urlencoded'),
        );

        flowLog(
          'friend/add 响应: ok=${resp.ok} code=${resp.code} msg=${resp.msg}',
        );
        await takeScreenshot(tester, 'mac_peer_02_after_apply');

        if (!resp.ok) {
          // already_requested = 申请已在途，对 Android 侧同样可用；
          // already_friends = 已是好友，没有待确认申请，须如实上报。
          if (resp.msg.contains('已发送过') ||
              resp.payload.toString().contains('already_requested')) {
            flowLog('申请已在途（重复发起被拒），Android 侧仍可用');
            return;
          }
          fail('好友申请失败: code=${resp.code} msg=${resp.msg}');
        }

        flowLog('好友申请已发往 uid=$_peerUid');
        drainKnownFrameworkExceptions(tester);
      },
      semanticsEnabled: false,
      timeout: const Timeout(Duration(minutes: 6)),
    );
  });
}
