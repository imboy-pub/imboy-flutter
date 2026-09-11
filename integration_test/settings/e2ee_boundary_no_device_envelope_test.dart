// integration_test/settings/e2ee_boundary_no_device_envelope_test.dart
//
// 路径1验收（reason 分流）：向本地 msg_c2c 注入与生产解密失败路径同构的
// `no_device_envelope` 失败行（密文构造时不含本设备信封——典型为换设备后
// 从服务端同步回的历史）。断言：
//   AT-B1  聊天页渲染**边界说明**文案，而非 [加密消息] 故障占位
//   AT-B2  点击该气泡**不弹**「无法解密此消息」恢复引导（恢复对这类
//          消息无济于事，引导只会制造走不通的出路）
//
// 运行（define 与批次165 同配方）：
//   flutter test integration_test/settings/e2ee_boundary_no_device_envelope_test.dart \
//     -d macos --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/utils/conversation_uk3_generator.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _aliceUid = '1000000051';

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 8);
  final ok = await _waitFor(
    tester,
    () => tester.any(find.text('消息')) || tester.any(find.text('说点什么')),
    seconds: 30,
  );
  if (!ok) {
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('路径1：no_device_envelope 渲染边界说明且不引导恢复', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── 造数前清残留 ──
    // 本用例与批次165 都会向 msg_c2c 注入失败行且历史上多次中断，残留行
    // 会让页级断言（页面上不得出现 [加密消息]）误判。这里清掉两族注入行。
    final db = await SqliteService.to.db;
    expect(db, isNotNull, reason: '前置：本地 SQLCipher 库已打开');
    await db!.rawDelete(
      "DELETE FROM ${MessageRepo.c2cTable} WHERE id LIKE 'bnd170_%'",
    );
    await db.rawDelete(
      "DELETE FROM ${MessageRepo.c2cTable} WHERE id LIKE 'bdg165_%'",
    );

    // ── 造数：注入 no_device_envelope 失败行 ──
    // text 取生产同款 e2eeFailedPlaceholderText('no_device_envelope')，
    // 与 service/message.dart / e2ee_service.dart 失败分支的落库形状一致。
    final boundaryText = E2EEService.e2eeFailedPlaceholderText(
      'no_device_envelope',
    );
    expect(boundaryText, isNot(t.chat.encryptedMessagePlaceholder));
    final failedMsg = MessageModel(
      'bnd170_${DateTime.now().microsecondsSinceEpoch}',
      autoId: 0,
      type: 'C2C',
      status: 11,
      fromId: int.parse(_aliceUid),
      toId: int.parse(_uid),
      payload: {
        'msg_type': 'text',
        'text': boundaryText,
        '_e2ee_failed': true,
        '_e2ee_reason': 'no_device_envelope',
      },
      isAuthor: 0,
      conversationUk3: ConversationUk3Generator.generate(
        type: 'C2C',
        currentUserId: _uid,
        peerId: _aliceUid,
      ),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      msgType: 'text',
    );
    await MessageRepo(tableName: MessageRepo.c2cTable).insert(failedMsg);
    flowLog('[造数] no_device_envelope 边界消息已注入本地 msg_c2c');

    router.go('/chat/$_aliceUid');
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byKey(const Key('chat_message_input'))),
        seconds: 12,
      ),
      isTrue,
      reason: '前置：与 alice 的会话页可达',
    );

    // ── AT-B1：渲染边界说明，不渲染 [加密消息] ──
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.text(boundaryText)),
        seconds: 12,
      ),
      isTrue,
      reason: 'AT-B1：no_device_envelope 应渲染边界说明文案',
    );
    expect(
      tester.any(find.text(t.chat.encryptedMessagePlaceholder)),
      isFalse,
      reason: 'AT-B1：同类消息不得再以 [加密消息] 故障占位呈现',
    );

    // ── AT-B2：点击不弹恢复引导 ──
    await tester.tap(find.text(boundaryText).first, warnIfMissed: false);
    await _pump(tester, seconds: 3);
    expect(
      tester.any(find.text(t.chat.e2eeRecoveryDecryptFailedTitle)),
      isFalse,
      reason: 'AT-B2：注定解不开的消息点击不得弹「无法解密此消息」恢复引导',
    );
    expect(
      tester.any(find.text(t.chat.e2eeRecoveryGoRecover)),
      isFalse,
      reason: 'AT-B2：不得出现「去恢复」入口',
    );

    // 清理注入行，避免残留误导后续轮次
    await MessageRepo(tableName: MessageRepo.c2cTable).delete(failedMsg.id);
  });
}
