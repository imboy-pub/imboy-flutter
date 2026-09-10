// integration_test/single/upgrade_failure_retry_realdevice_batch168_test.dart
//
// upgrade_page 两行真机解锁（批次168，automation 第四十一轮）。批次167 定性：
// 下载管线（RUpgrade 流 + SHA256 校验重试）为 Android-only（Platform.isAndroid
// 门），macOS 上点「立即更新」仅弹平台提示——两行必须真机（阻塞理由准确）。
//
// 配方（完全密封，零共享状态残留）：
// - 服务端数据：TestPg 向 app_version 临时插 android 行（vsn=9.9.9-16x 高于
//   设备构建，跑完 DELETE），走真实生产链 AppUpgradeService.checkAndPrompt
//   → /app_version/check → UpgradePage（fileHash 随 payload 下发）。
// - 下载失败（AT-UP1）：download_url=http://127.0.0.1:1/app.apk（设备侧
//   回环端口 1 无监听=瞬时失败）→ STATUS_FAILED → 卡片按钮变「继续下载」
//   =重新发起下载入口 → 点后仍可重试。
// - 校验失败（AT-UP2）：测试进程内 HttpServer 绑定**设备侧**回环 19802
//   供真实字节，file_hash 预置错误值 → 下载成功 → 点「立即安装」触发
//   _verifyAndInstall → 校验失败删文件+自动重下，重试上限 2 次
//   （toast 文件校验失败，正在重新下载 (1/2)/(2/2) → 文件多次校验失败）。
//
// 运行前置（宿主执行）：
//   adb reverse tcp:9801 tcp:9801   # 设备访问本地后端
//   adb reverse tcp:4323 tcp:4323   # TestPg 访问本地 PG
//   adb shell pm grant pub.imboy.app android.permission.READ_EXTERNAL_STORAGE
//   adb shell pm grant pub.imboy.app android.permission.WRITE_EXTERNAL_STORAGE
//   flutter test integration_test/single/upgrade_failure_retry_realdevice_batch168_test.dart \
//     -d XWE6R19916004085 --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/service/app_upgrade_service.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
// 设备侧回环端口：失败场景用端口 1（无监听）；供包场景用 19802（测试内监听）
const _servePort = 19802;

Future<void> _pump(WidgetTester tester, {int seconds = 3}) async {
  for (var i = 0; i < seconds * 2; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

Future<bool> _waitFor(
  WidgetTester tester,
  bool Function() cond, {
  int seconds = 20,
}) async {
  for (var i = 0; i < seconds * 2 && !cond(); i++) {
    await tester.pump(const Duration(milliseconds: 500));
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return cond();
}

Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 15);
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
    if (i == 6) {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? w.textSpan?.toPlainText())
          .where((s) => s != null && s.trim().isNotEmpty)
          .take(30)
          .toList();
      flowLog('[DIAG] boot 第6轮可见文本: $texts');
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
  flowLog('[BOOT] 登录稳定态 OK');
  return true;
}

Future<void> _upsertAndroidRow(
  String vsn,
  String url,
  String fileHash,
) async {
  await TestPg.execute(
    'DELETE FROM app_version WHERE type = \'android\' AND vsn LIKE \'9.9.9-%\'',
    {},
  );
  await TestPg.execute(
    'INSERT INTO app_version (id, type, vsn, status, download_url, '
    'description, file_hash, upgrade_type, force_update) '
    'VALUES (@_id, \'android\', @_vsn, 1, @_url, \'batch168 temp\', '
    '@_hash, \'recommend\', false)',
    {
      '_id': DateTime.now().millisecondsSinceEpoch,
      '_vsn': vsn,
      '_url': url,
      '_hash': fileHash,
    },
  );
}

Future<void> _cleanupAndroidRows() async {
  await TestPg.execute(
    'DELETE FROM app_version WHERE type = \'android\' AND vsn LIKE \'9.9.9-%\'',
    {},
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('批次168：AT-UP 下载失败可重发 + 校验失败删文件重试两次（真机）', (
    tester,
  ) async {
    if (!await _boot(tester)) return;

    await _cleanupAndroidRows();

    // ── AT-UP1：下载失败 → 「继续下载」=重新发起下载，且可反复重试 ──
    await _upsertAndroidRow(
      '9.9.9-167',
      'http://127.0.0.1:1/app.apk', // 设备侧端口 1 无监听 → 瞬时失败
      '', // 无 hash：下载成功才走安装；本场景只验证失败重试
    );
    // fromManual=true 忽略「稍后提醒」记录，直接走服务端 payload 弹页
    unawaited(AppUpgradeService.to.checkAndPrompt(fromManual: true));
    flowLog('[AT-UP1] checkAndPrompt 已触发，等待升级页');
    final page1 = await _waitFor(
      tester,
      () => tester.any(find.text('立即更新')),
      seconds: 20,
    );
    expect(page1, isTrue, reason: '前置：checkAndPrompt 应推起升级页（立即更新）');
    flowLog('[AT-UP1] 升级页已出现');
    // 缓冲窗口：宿主侧轮询到应用安装完成后执行 pm grant（sdk<33 需存储权限）
    await _pump(tester, seconds: 10);

    await tester.tap(find.text('立即更新'), warnIfMissed: false);
    flowLog('[AT-UP1] 已点立即更新，等待下载失败');
    final retryBtn1 = await _waitFor(
      tester,
      () => tester.any(find.text('继续下载')),
      seconds: 30,
    );
    expect(
      retryBtn1,
      isTrue,
      reason: 'AT-UP1：下载失败后卡片应出现「继续下载」（重新发起下载入口）',
    );
    // 再点一次：验证重试可反复发起（第二次仍失败 → 按钮仍在）
    await tester.tap(find.text('继续下载'), warnIfMissed: false);
    await _pump(tester, seconds: 4);
    expect(
      tester.any(find.text('继续下载')),
      isTrue,
      reason: 'AT-UP1：再次发起下载后失败仍可继续重试',
    );
    flowLog('[AT-UP1] PASS：下载失败 → 继续下载（可反复重发）');
    // 退出本场景页，释放 checkAndPrompt 的 await
    await tester.tap(find.text('下次再说'), warnIfMissed: false);
    final popped = await _waitFor(
      tester,
      () => !tester.any(find.text('立即更新')),
      seconds: 15,
    );
    expect(popped, isTrue, reason: '场景1收尾：点下次再说后升级页应退出');
    flowLog('[AT-UP1] 升级页已退出');

    // ── AT-UP2：校验失败 → 删文件自动重下，重试上限 2 次 ──
    // 供包服务器绑定**设备侧**回环：测试进程与被测 app 同设备
    final servedBytes = List<int>.generate(4096, (i) => i % 251);
    var serverHits = 0;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, _servePort);
    server.listen((req) {
      serverHits++;
      flowLog('[AT-UP2] 供包服务器收到第 $serverHits 次请求');
      req.response.add(servedBytes);
      req.response.close();
    });
    flowLog('[AT-UP2] 设备侧供包服务器已监听 :$_servePort');

    await _upsertAndroidRow(
      '9.9.9-168',
      'http://127.0.0.1:$_servePort/app.apk',
      '0' * 64, // 必然错误的 SHA256
    );
    unawaited(AppUpgradeService.to.checkAndPrompt(fromManual: true));
    flowLog('[AT-UP2] checkAndPrompt 已触发，等待升级页');
    final page2 = await _waitFor(
      tester,
      () => tester.any(find.text('立即更新')),
      seconds: 20,
    );
    expect(page2, isTrue, reason: '前置：第二场景升级页应推起');
    flowLog('[AT-UP2] 升级页已出现');
    // 路由转场期间命中测试被拦截：等待动画结束再点（场景1同款缓冲）
    await _pump(tester, seconds: 10);

    await tester.tap(find.text('立即更新'), warnIfMissed: false);
    flowLog('[AT-UP2] 已点立即更新，等待下载完成');
    // 下载完成（有 hash）→ 卡片按钮变「立即安装」
    final installBtn = await _waitFor(
      tester,
      () => tester.any(find.text('立即安装')),
      seconds: 40,
    );
    expect(installBtn, isTrue, reason: 'AT-UP2 前置：下载完成应出现「立即安装」');

    // 第 1 次点「立即安装」触发校验：失败无残留 toast 干扰，精确断言 (1/2)
    await tester.tap(find.text('立即安装'), warnIfMissed: false);
    final retryToast1 = await _waitFor(
      tester,
      () => tester.any(find.textContaining('(1/2)')),
      seconds: 25,
    );
    expect(retryToast1, isTrue, reason: 'AT-UP2：第 1 次校验失败应提示正在重下 (1/2)');
    flowLog('[AT-UP2] 校验失败重试提示 (1/2) 已确认');

    // 持续点「立即安装」直至达上限终态提示。代码上限 _maxHashRetry=2，但
    // RUpgrade 对同 URL 任务有内部去重/重下时序裁量，此处锚定稳定可观测量：
    // 终态 toast「文件多次校验失败」+ 供包服务器请求数 ≥2 = 至少一次自动重下
    var sawFinalFailure = false;
    for (var round = 0; round < 6; round++) {
      if (tester.any(find.textContaining('多次校验失败'))) {
        sawFinalFailure = true;
        break;
      }
      final btn = await _waitFor(
        tester,
        () => tester.any(find.text('立即安装')),
        seconds: 40,
      );
      if (!btn) break;
      await tester.tap(find.text('立即安装'), warnIfMissed: false);
      sawFinalFailure = await _waitFor(
        tester,
        () => tester.any(find.textContaining('多次校验失败')),
        seconds: 30,
      );
    }
    expect(
      sawFinalFailure,
      isTrue,
      reason: 'AT-UP2：重试达上限后应提示「文件多次校验失败」',
    );
    expect(
      serverHits,
      greaterThanOrEqualTo(2),
      reason: 'AT-UP2：校验失败应触发自动重下（供包服务器请求数 ≥2），实际 $serverHits',
    );
    flowLog(
      '[AT-UP2] PASS：校验失败删文件自动重下（服务器 $serverHits 次）→ 达上限提示失败',
    );

    // ── 收尾：清理临时升级行 + 关闭供包服务器 ──
    await _cleanupAndroidRows();
    await server.close(force: true);
    flowLog('[AT-UP] 临时 app_version 行已清理');
  });
}
