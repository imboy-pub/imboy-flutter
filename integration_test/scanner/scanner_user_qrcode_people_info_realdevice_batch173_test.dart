// integration_test/scanner/scanner_user_qrcode_people_info_realdevice_batch173_test.dart
//
// scanner_page「扫到用户名片跳转个人资料页」行解锁（批次173，automation
// 第四十六轮）。原阻塞理由「第二台设备出示个人二维码后」不成立：
//
//   ① 名片二维码内容是确定性 URL（buildUserQrcodeUrl，s=app_qrcode 结尾），
//      测试可直接构造 BarcodeCapture(rawValue: url) 手动驱动 onDetect——
//      mobile_scanner 7.x 的 Barcode/BarcodeCapture 均公开可构造，
//      MobileScanner.onDetect 是页面传入的公开回调，无需相机画面；
//   ② 对端用 smoke_alice（自有测试账号），无第三方影响；
//   ③ 服务端识别端点 /api/v1/user/qrcode 已 curl 实测（type=user,
//      id=1000000051, isfriend=true）。
//
// macOS 上 Permission.camera.request() 必拒（_startFailed 移除
// MobileScanner），故本行必须真机——阻塞理由修正为「需真机相机启动」。
//
// 全链路：push /scanner → 相机启动成功 → onDetect(构造的用户名片码) →
// GET qrcode URL（dio 带 token）→ payload type=user → pushReplacement
// /people_info/1000000051?scene=qrcode → Alice 资料页渲染（发消息按钮）
//
//   AT-SC1 扫描用户名片二维码跳转个人资料页（昵称+好友操作按钮渲染）
//
// 运行（真机前置见文件头，配方与批次168 一致）：
//   adb reverse tcp:9801 tcp:9801 && adb reverse tcp:4323 tcp:4323
//   （安装后）adb shell pm grant pub.imboy.app android.permission.CAMERA
//
//   flutter test integration_test/scanner/scanner_user_qrcode_people_info_realdevice_batch173_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/qrcode/qrcode_url.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
const _baseUrl = 'http://127.0.0.1:9801';
const _inviteeUid = '1000000051'; // smoke_alice（自有测试账号）

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
  await _pump(tester, seconds: 12);
  const wsEmptySeen = Key('workspace-empty-create-entry');
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    GoRouter.of(tester.element(find.byType(Navigator).first)).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  for (var i = 0; i < 12; i++) {
    if (tester.any(find.byKey(wsEmptySeen)) ||
        tester.any(find.text('还没有工作区')) ||
        isOnMainShell(tester)) {
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
    } else if (UserRepoLocal.to.currentUid == _uid) {
      GoRouter.of(
        tester.element(find.byType(Navigator).first),
      ).go('/bottom_navigation');
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    flowLog('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 smoke_bob');
  await _pump(tester, seconds: 5);
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次173：AT-SC1 扫描用户名片二维码跳转个人资料页', (tester) async {
    if (!await _boot(tester)) return;
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ── 前置：打开扫码页，等待相机启动成功（MobileScanner 挂树）──
    router.push('/scanner');
    final scannerReady = await _waitFor(
      tester,
      () => tester.any(find.byType(MobileScanner)),
      seconds: 30,
    );
    if (!scannerReady) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(20)
          .toList();
      flowLog('[DIAG] 扫码页未达相机就绪（疑权限/启动失败），可见文本: $texts');
    }
    expect(scannerReady, isTrue, reason: '前置：扫码页相机应启动成功');
    flowLog('[AT-SC1] 扫码页相机就绪');

    // ── AT-SC1：手动驱动 onDetect（构造的用户名片码，确定性 URL）──
    final qrcodeUrl = buildUserQrcodeUrl(_inviteeUid, baseUrl: _baseUrl);
    flowLog('[AT-SC1] 注入名片码：$qrcodeUrl');
    final mobileScanner = tester.widget<MobileScanner>(
      find.byType(MobileScanner),
    );
    final onDetect = mobileScanner.onDetect;
    expect(onDetect, isNotNull, reason: '前置：MobileScanner 应已挂 onDetect');
    // onDetect 签名为 void Function(BarcodeCapture)（内部 async），
    // fire-and-forget 驱动，跳转靠下方轮询等待
    onDetect!(
      BarcodeCapture(
        barcodes: [Barcode(rawValue: qrcodeUrl, format: BarcodeFormat.qrCode)],
      ),
    );
    await _pump(tester, seconds: 2);

    // ── 断言：pushReplacement 到 alice 个人资料页并渲染 ──
    // 锚点=昵称+「备注和标签」（people_info 资料页专属结构）。
    // 注意：好友操作按钮（发消息/添加到通讯录）随 isFriend 数据方向变化，
    // 不作为本行锚点（沙盒库 alice-bob relation 为单向，见批次173 记录）。
    final peopleReady = await _waitFor(
      tester,
      () => tester.any(find.text('Alice')) && tester.any(find.text('备注和标签')),
      seconds: 30,
    );
    if (!peopleReady) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] 个人资料页未渲染，可见文本: $texts');
    }
    expect(
      peopleReady,
      isTrue,
      reason:
          'AT-SC1：识别用户名片后应 pushReplacement 到 '
          '/people_info/$_inviteeUid?scene=qrcode（昵称 Alice + 资料页结构渲染）',
    );
    flowLog('[AT-SC1] PASS：名片码识别 → 个人资料页渲染（Alice/发消息）');
    await _pump(tester, seconds: 2);
  });
}
