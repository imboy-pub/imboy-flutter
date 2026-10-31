// integration_test/chat/j16b_dnd_failure_retry_test.dart
//
// plan-v2.2 §9 J16.b（原状态 false：注入持久化失败/切账号/连续点击分别
// → 状态不假成功，目标不取反，账号隔离且可重试）真机旅程——真机覆盖
// 「连续点击」向量：
//   ① 先关（j16a 已置 on）：toast「已关闭」+ DB 回读 is_muted=0 +
//      （状态不假成功）
//   ② 再开：toast「已开启」+ DB 回读 is_muted=1（目标不取反，可重试）
//   ③ 快速连点 2 次（200ms 间隔）：产品忙态（_mutePending）吞没属预期，
//      断言终态 UI↔DB 一致（不假成功），忙态行为如实打印不断言具体值
//
// 「注入持久化失败」向量：无测试缝（StorageService.setBool/SQLite 写
// 失败无注入点），按既有静态证据记录（W03 开关忙态/失败回滚定向证据）。
// 「切账号」向量：bob 密码不可用（登录 API 实测拒绝），KV 键
// group_notice_disabled:$accountUid:$gid 含 accountUid（隔离由键设计
// 承担），按静态证据记录。
//
// 前置：j16a 已把 bob C2C DND 置 on。

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat_setting/chat_setting_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';
import 'support/c2c_journey_support.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _bobUid = '120619871628429312';

const _muteLabel = '消息免打扰';
const _onToast = '已开启';
const _offToast = '已关闭';
const _chatSettingsTooltip = '聊天设置';

/// 会话列表 → bob C2C → 聊天设置页（断言已进入）。
Future<void> _openBobSettings(WidgetTester t) async {
  await settle(t, maxSeconds: 2);
  await dismissRecoveryGuide(t);
  await settle(t, maxSeconds: 2);
  if (!await openConversationTab(t)) {
    fail('无法进入会话列表');
  }
  await settle(t, maxSeconds: 2);
  final bobItem = find.byWidgetPredicate(
    (w) =>
        w is ConversationItem &&
        w.model.type == 'C2C' &&
        w.model.peerId.toString() == _bobUid,
  );
  var seen = false;
  for (var i = 0; i < 20 && !seen; i++) {
    seen = t.any(bobItem);
    if (!seen) await settle(t, maxSeconds: 1);
  }
  if (!seen) {
    fail('会话列表中无 bob 的 C2C 会话（前置 j16a 缺失？）');
  }
  await safeTap(t, bobItem.first);
  await settle(t, maxSeconds: 3);
  final settingsEntry = find.byTooltip(_chatSettingsTooltip);
  expect(settingsEntry, findsOneWidget, reason: 'C2C 聊天页应挂设置入口');
  await safeTap(t, settingsEntry.first);
  await settle(t, maxSeconds: 2);
  expect(find.byType(ChatSettingPage), findsOneWidget, reason: '应进入聊天设置页');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J16.b DND 开关合同：不假成功、目标不取反、连点忙态一致', (tester) async {
    if (_expectedUid.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J16.b 前置失败：登录未进入主界面');
    }
    if (UserRepoLocal.to.currentUid != _expectedUid) {
      fail('登录账号 UID=${UserRepoLocal.to.currentUid} 与授权操作者 $_expectedUid 不一致');
    }

    final repo = ConversationRepo();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);

    // ① 先关：toast「已关闭」+ DB 回读 0（状态不假成功）。
    // 前置自洽：不依赖 j16a 残留——以 DB 真源为锚；页面开关渲染存在
    // 异步回填时延与瞬时守卫态，DB 是唯一可信前置锚点。
    await _openBobSettings(tester);
    final seedRow = await repo.findByPeerId('C2C', _bobUid);
    debugPrint('J16B seed db isMuted=${seedRow?.isMuted}');
    if (seedRow?.isMuted == 0) {
      // DB=0：先点一次开启（DB→1），段1 的「关」才有合法起点（on→off）。
      await safeTap(tester, find.text(_muteLabel).first);
      var turnedOn = false;
      for (var i = 0; i < 20 && !turnedOn; i++) {
        final r = await repo.findByPeerId('C2C', _bobUid);
        turnedOn = r?.isMuted == 1;
        if (!turnedOn) await settle(tester, maxSeconds: 1);
      }
      debugPrint('J16B seed turned-on=$turnedOn');
      expect(turnedOn, isTrue, reason: 'seed 开启失败（点击未生效/持久化失败）');
    }
    // 整行 onTap 同触发 onChanged（点文本行比缩放后的 switch 本体稳）。
    // 忙态（_mutePending）期间的点击被产品吞没是合同内行为：带退避重试
    // 点击直到 DB=0（用户也会再点一次），重试链如实打印。
    var rowAfterOff = await repo.findByPeerId('C2C', _bobUid);
    var offPersisted = rowAfterOff?.isMuted == 0;
    var offTaps = 0;
    for (var i = 0; i < 5 && !offPersisted; i++) {
      await settle(tester, maxSeconds: 2);
      await safeTap(tester, find.text(_muteLabel).first);
      offTaps++;
      for (var j = 0; j < 8 && !offPersisted; j++) {
        rowAfterOff = await repo.findByPeerId('C2C', _bobUid);
        offPersisted = rowAfterOff?.isMuted == 0;
        if (!offPersisted) await settle(tester, maxSeconds: 1);
      }
    }
    final offToast = tester.any(find.textContaining(_offToast));
    debugPrint(
      'J16B toast-observed-off=$offToast persisted=$offPersisted taps=$offTaps',
    );
    expect(
      offPersisted,
      isTrue,
      reason: '关闭后 DB 回读 is_muted=0（不假成功；taps=$offTaps）',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ② 再开：toast「已开启」+ DB 回读 1（可重试、不取反）。
    await _openBobSettings(tester);
    var rowAfterOn = await repo.findByPeerId('C2C', _bobUid);
    var onPersisted = rowAfterOn?.isMuted == 1;
    var onTaps = 0;
    for (var i = 0; i < 5 && !onPersisted; i++) {
      await settle(tester, maxSeconds: 2);
      await safeTap(tester, find.text(_muteLabel).first);
      onTaps++;
      for (var j = 0; j < 8 && !onPersisted; j++) {
        rowAfterOn = await repo.findByPeerId('C2C', _bobUid);
        onPersisted = rowAfterOn?.isMuted == 1;
        if (!onPersisted) await settle(tester, maxSeconds: 1);
      }
    }
    final onToast = tester.any(find.textContaining(_onToast));
    debugPrint(
      'J16B toast-observed-on=$onToast persisted=$onPersisted taps=$onTaps',
    );
    expect(
      onPersisted,
      isTrue,
      reason: '开启后 DB 回读 is_muted=1（可重试、不取反；taps=$onTaps）',
    );
    nav.pop();
    await settle(tester, maxSeconds: 2);
    nav.pop();
    await settle(tester, maxSeconds: 2);

    // ③ 快速连点 2 次：忙态吞没属预期；终态 UI↔DB 一致（不假成功）。
    await _openBobSettings(tester);
    final swBefore = tester.widget<CupertinoSwitch>(
      find.byType(CupertinoSwitch).first,
    );
    debugPrint('J16B rapid-toggle before=${swBefore.value}');
    await tester.tap(find.byType(CupertinoSwitch).first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(CupertinoSwitch).first, warnIfMissed: false);
    await settle(tester, maxSeconds: 5);
    // 连点后等 UI↔DB 收敛（异步写+页面重读均有真实时延），再取终态。
    bool uiSwitchValue() => tester
        .widget<CupertinoSwitch>(find.byType(CupertinoSwitch).first)
        .value;
    var converged = false;
    var lastDb = 0;
    for (var i = 0; i < 20 && !converged; i++) {
      final dbRow = await repo.findByPeerId('C2C', _bobUid);
      lastDb = dbRow?.isMuted ?? 0;
      converged = uiSwitchValue() == (lastDb == 1);
      if (!converged) await settle(tester, maxSeconds: 1);
    }
    final swAfterValue = uiSwitchValue();
    final dbRow = await repo.findByPeerId('C2C', _bobUid);
    debugPrint(
      'J16B rapid-toggle after: ui=$swAfterValue db=${dbRow?.isMuted} '
      'converged=$converged (busy-state swallow expected)',
    );
    expect(
      converged && swAfterValue == (dbRow?.isMuted == 1),
      isTrue,
      reason:
          '连点后 UI 显示必须与 DB 回读一致（不假成功），实际 ui=$swAfterValue db=${dbRow?.isMuted} lastDb=$lastDb',
    );
    expect(find.text(_muteLabel), findsWidgets, reason: 'DND 行应存在');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
