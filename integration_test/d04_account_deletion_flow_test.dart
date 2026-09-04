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

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  for (var i = 0; i < seconds * 2; i++) {
    if (anyText(tester, fragments)) return true;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 100));
  }
  return anyText(tester, fragments);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets(
    'D-04 账号注销全流程：申请 → 状态横幅 → 撤销恢复',
    (tester) async {
      await ensureAppLaunched(tester);

      // ── 欢迎页/登录：自动登录到主 Shell ──
      if (!await checkPreconditions(tester)) return;

      // ── 进入注销账号页 ──
      final appCtx = tester.element(find.byType(MaterialApp).first);
      GoRouter.of(appCtx).push('/logout_account');
      await settle(tester, maxSeconds: 4);

      // C5：留存类别公示（审计日志/财务记录），双语兜底
      final hasRetainedNote = await waitForText(tester, [
        '审计日志',
        'audit logs',
      ]);
      expect(hasRetainedNote, isTrue,
          reason: '注销页应公示数据留存说明（D-04 C5）');

      // C2：确认条款勾选（CupertinoCheckbox）
      final checkbox = find.byType(CupertinoCheckbox);
      if (tester.any(checkbox)) {
        await tester.tap(checkbox.first);
        await settle(tester, maxSeconds: 2);
      } else {
        // 兜底：点条款行
        final tile = find.textContaining('已经阅读').evaluate().isNotEmpty
            ? find.textContaining('已经阅读')
            : find.textContaining('read and agree');
        await tester.tap(tile.first);
        await settle(tester, maxSeconds: 2);
      }

      // ── 申请注销：二次确认弹窗 → 确认 ──
      final deleteBtn = find.widgetWithText(
        CupertinoButton,
        '注销账号',
      );
      final deleteBtnEn = find.widgetWithText(
        CupertinoButton,
        'Delete account',
      );
      if (tester.any(deleteBtn)) {
        await tester.tap(deleteBtn.first);
      } else if (tester.any(deleteBtnEn)) {
        await tester.tap(deleteBtnEn.first);
      } else {
        fail('未找到注销提交按钮（C2/C6 证据失败）');
      }
      await settle(tester, maxSeconds: 3);

      // 确认弹窗：点破坏性确认（文案=注销账号/Delete account）
      final confirm = find.widgetWithText(
        CupertinoDialogAction,
        '注销账号',
      );
      final confirmEn = find.widgetWithText(
        CupertinoDialogAction,
        'Delete account',
      );
      if (tester.any(confirm)) {
        await tester.tap(confirm.first);
      } else if (tester.any(confirmEn)) {
        await tester.tap(confirmEn.first);
      }
      await settle(tester, maxSeconds: 5);

      // 申请成功后应用登出并回到欢迎页
      await settle(tester, maxSeconds: 5);

      // ── 重新登录：宽限期内账号可登录，注销页应显示状态横幅 ──
      if (!await checkPreconditions(tester)) return;
      await GoRouter.of(tester.element(find.byType(MaterialApp).first))
          .push('/logout_account');
      await settle(tester, maxSeconds: 4);

      // C3：状态横幅（申请已提交/预期完成时间）
      final bannerShown = await waitForText(tester, [
        '注销申请已提交',
        'Deletion request submitted',
      ]);
      expect(bannerShown, isTrue, reason: '宽限期内应显示注销状态横幅（C3）');

      // C4：撤销入口存在且可用
      final cancelTile = find.textContaining('撤销注销申请').evaluate().isNotEmpty
          ? find.textContaining('撤销注销申请')
          : find.textContaining('Cancel deletion request');
      await tester.tap(cancelTile.first);
      await settle(tester, maxSeconds: 4);

      // 撤销后横幅消失（状态 cancelled），账号仍登录可用
      final bannerGone = !tester.any(find.textContaining('注销申请已提交')) &&
          !tester.any(find.textContaining('Deletion request submitted'));
      expect(bannerGone, isTrue, reason: '撤销后状态横幅应消失（C4）');

      // ── 恢复现场：账号保持无注销请求状态 ──
      // （撤销后 user_deletion_request.status=cancelled，无需再操作）
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
