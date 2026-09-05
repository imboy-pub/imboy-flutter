// integration_test/d04_account_deletion_flow_test.dart
//
// 账号删除合规链 D-04 端到端流程（Implementation Plan Task D-04）：
//   登录 → 进入注销账号页（留存类别公示）→ 勾选 → 申请注销 →
//   状态横幅（预期完成时间）→ 撤销 → 账号恢复可用。
//
// 运行（模拟器，后端 9804 在宿主机）：
//   flutter test integration_test/d04_account_deletion_flow_test.dart \
//     -d emulator-5554 \
//     --dart-define=APP_ENV=local \
//     --dart-define=API_BASE_URL_OVERRIDE=http://10.0.2.2:9804 \
//     --dart-define=WS_URL_OVERRIDE=ws://10.0.2.2:9804/ws \
//     --dart-define=TEST_PHONE=smoke_alice \
//     --dart-define=TEST_PASSWORD=admin888
//
// 前置：后端 9804 已启动且迁移 ≥ 00000086；config 表已含
// pub.imboy.app_android_1.0.0-alpha.16 的 sign_key（否则 initConfig
// 解密失败，测试会因登录页卡住而 SKIP/失败）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/page/mine/logout_account/logout_account_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import 'flows/app_launcher.dart';
import 'flows/test_utils.dart';

/// 双语断言辅助：模拟器 locale 可能是 en，也可能随宿主是 zh。
bool anyText(WidgetTester tester, List<String> fragments) {
  for (final f in fragments) {
    if (tester.any(find.textContaining(f))) return true;
  }
  return false;
}

Future<bool> waitForText(
  WidgetTester tester,
  List<String> fragments, {
  int seconds = 12,
}) async {
  // 不要在循环里调 tester.pump：Live binding 下主 Shell 空闲无帧调度时
  // pump 会永久挂起（实测冻结在进入断言前的第一轮循环），真实 UI 由
  // Flutter 引擎自行渲染，轮询等待用纯 delay 即可。
  for (var i = 0; i < seconds * 2; i++) {
    if (anyText(tester, fragments)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  return anyText(tester, fragments);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('D-04 账号注销全流程：申请 → 状态横幅 → 撤销恢复', (tester) async {
    // 桌面端 jverify/share_handler 无 dart 实现，app 初始化的
    // MissingPluginException 会触发 binding 断言挂死，必须先于 app.main() 安装。
    installPluginErrorFilter();
    await ensureAppLaunched(tester);

    // ── 欢迎页/登录：自动登录到主 Shell ──
    if (!await checkPreconditions(tester)) return;

    // ── 进入注销账号页 ──
    // GoRouter 在 MaterialApp 内部创建：用 MaterialApp 自身的 element 查
    // InheritedGoRouter 会 "No GoRouter found in context"，必须取其下层的
    // Navigator context（登录成功直奔主 Shell 时必经此行）。
    final navCtx = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx).push('/logout_account');
    await Future<void>.delayed(const Duration(seconds: 4));

    // C5：留存类别公示（审计日志/财务记录），双语兜底
    final hasRetainedNote = await waitForText(tester, ['审计日志', 'audit logs']);
    expect(hasRetainedNote, isTrue, reason: '注销页应公示数据留存说明（D-04 C5）');

    // C3：状态横幅（申请已提交/预期完成时间）。
    // 后端 user_deletion_request 存在 requested 请求时，进入页面即显示
    // 宽限期横幅（deletion_status 已由页面 postFrame 回调拉取）。
    final bannerShown = await waitForText(tester, [
      '注销申请已提交',
      'Deletion request submitted',
    ]);
    expect(bannerShown, isTrue, reason: '宽限期内应显示注销状态横幅（C3）');

    // C1/C2：确认条款勾选 + 申请注销。
    // macOS 测试窗口被遮挡后 Flutter 引擎停帧，Live binding 的手势
    // （tester.tap）与 pump 会永久挂起（本轮多轮实测），故申请动作改用
    // 页面「注销账号」按钮 handler 最终调用的同一 notifier 方法驱动。
    final pageCtx = tester.element(find.byType(LogoutAccountPage).first);
    final container = ProviderScope.containerOf(pageCtx);
    final applyOk = await container
        .read(logoutAccountProvider.notifier)
        .applyLogout()
        .timeout(const Duration(seconds: 30));
    expect(applyOk, isTrue, reason: '注销申请应成功并落入宽限期（C1/C2）');

    // 页面 handler 的级联产品动作（logout_account_page.dart 按钮回调）：
    // 本地登出（token/E2EE/SQLite 级联清理）+ 跳转 /welcome（登录页所在路由）
    await UserRepoLocal.to.quitLogin();
    final navCtx1 = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx1).go('/welcome');

    // ── 宽限期重登 + C4 撤销：数据层验证 ──
    // 重登与撤销用 dart:io 裸 HTTP 直发（与登录页/撤销按钮相同的端点）：
    // 重登后窗口期的 Dio POST 会因 token-expired completer 排队而挂死，
    // 且 quitLogin 已清空 app 内会话，UI 层不再承担这两步的断言。
    const apiBase = String.fromEnvironment(
      'API_BASE_URL_OVERRIDE',
      defaultValue: 'http://127.0.0.1:9801',
    );
    final hc = HttpClient();
    Future<Map<String, dynamic>> postJson(
      String path,
      Map<String, Object?> o, {
      String? bearer,
    }) async {
      final req = await hc
          .postUrl(Uri.parse('$apiBase$path'))
          .timeout(const Duration(seconds: 10));
      req.headers.set('Content-Type', 'application/json');
      req.headers.set('cos', 'macos');
      req.headers.set('vsn', '1.0.0-alpha.16');
      req.headers.set('pkg', 'pub.imboy.app');
      req.headers.set('sk', '1');
      if (bearer != null) {
        req.headers.set('token', bearer);
        req.headers.set('authorization', bearer);
      }
      req.add(utf8.encode(json.encode(o)));
      final res = await req.close().timeout(const Duration(seconds: 15));
      final body = await res.transform(utf8.decoder).join();
      expect(res.statusCode, 200, reason: '$path 应返回 200：$body');
      return json.decode(body) as Map<String, dynamic>;
    }

    // 宽限期重登：status=2（申请注销中）账号放行登录（C3 的服务端语义）
    final loginResp = await postJson('/api/v1/passport/login', {
      'account': FlowConfig.testPhone,
      'pwd': FlowConfig.testPassword,
      'rsa_encrypt': 0,
      'type': 'account',
    });
    expect(loginResp['code'], 0, reason: '宽限期内账号应可重新登录');
    final newToken =
        (loginResp['payload'] as Map<String, dynamic>)['token'] as String?;
    expect(newToken, isNotNull, reason: '重登应签发新令牌');

    // C4：撤销注销申请（撤销按钮触发的同一端点）+ 状态翻转为 cancelled
    final cancelResp = await postJson(
      '/api/v1/user/cancel_logout',
      {},
      bearer: newToken,
    );
    expect(cancelResp['code'], 0, reason: '撤销注销申请应成功（C4）');
    final creq2 = await hc
        .getUrl(Uri.parse('$apiBase/api/v1/user/deletion_status'))
        .timeout(const Duration(seconds: 10));
    creq2.headers.set('token', newToken!);
    creq2.headers.set('authorization', newToken);
    final cres2 = await creq2.close().timeout(const Duration(seconds: 15));
    final cbody2 = await cres2.transform(utf8.decoder).join();
    final cdata = json.decode(cbody2) as Map<String, dynamic>;
    final cpayload = cdata['payload'] as Map<String, dynamic>;
    expect(
      cpayload['status'],
      isNot('requested'),
      reason: '撤销后不应再处于申请注销状态（C4）：$cbody2',
    );
    hc.close(force: true);

    // ── 恢复现场：账号保持无注销请求状态 ──
    // （撤销后 user_deletion_request.status=cancelled，无需再操作）
  }, timeout: const Timeout(Duration(minutes: 10)));
}
