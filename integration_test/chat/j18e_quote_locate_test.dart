// integration_test/chat/j18e_quote_locate_test.dart
//
// plan-v2.2 §9 J18.e（引用目标已加载 → 点击引用 → 滚动/高亮目标或给出
// 可行动失败）真机旅程：登录 demo_alice → 打开与 demo_bob 的 C2C →
// 长按历史填充消息 → 「引用」→ 发送带引用消息 → 点击引用条 →
// 断言目标气泡从屏外滚动进入视口（或出现可行动失败提示）。
//
// 前置（fixture 在测试外完成）：
//   后端本地 daemon 绑定合成库；demo_alice/demo_bob 互为好友；
//   bob→alice 已预置 20 条填充消息「J18E 填充消息 #NN」。
//
// 运行：
//   flutter test integration_test/chat/j18e_quote_locate_test.dart \
//     -d <real_device_id> \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9800 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9800/ws \
//     --dart-define=TEST_PHONE=demo_alice \
//     --dart-define=TEST_PASSWORD=<pwd> \
//     --dart-define=TEST_EXPECTED_UID=<alice-uid> \
//     --dart-define=PEER_UID=<bob-uid> \
//     --dart-define=PEER_TITLE=演示用户Bob \
//     --dart-define=TEST_ALLOW_BUSINESS_WRITES=true

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'package:integration_test/integration_test.dart';

import '../flows/app_launcher.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _peerUid = String.fromEnvironment('PEER_UID');
const _peerTitle = String.fromEnvironment('PEER_TITLE');

const _markerPrefix = '[J18E-LOCATE]';

/// 与 e2e_chat_test 相同的会话列表判定（该实现为私有，此处复刻）。
bool _isOnConvList(WidgetTester t) =>
    t.any(
      find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'ConversationPage',
      ),
    ) ||
    (t.any(find.byIcon(Icons.search)) &&
        t.any(find.byIcon(Icons.add_circle_outline)));

Future<bool> _openConversationTab(WidgetTester t) async {
  if (_isOnConvList(t)) return true;
  await tapAny(t, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
  ]);
  for (int i = 0; i < 5; i++) {
    await settle(t, maxSeconds: 1);
    if (_isOnConvList(t)) return true;
  }
  return false;
}

/// 返回所有匹配项在屏幕上的纵向位置（top）。
List<double> _topsOf(WidgetTester t, Finder finder) {
  final tops = <double>[];
  for (final element in finder.evaluate()) {
    final ro = element.renderObject;
    if (ro is RenderBox && ro.hasSize && ro.attached) {
      tops.add(ro.localToGlobal(Offset.zero).dy);
    }
  }
  return tops;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J18.e 引用目标已加载：点击引用条滚动定位目标气泡', (tester) async {
    if (_expectedUid.isEmpty || _peerUid.isEmpty || _peerTitle.isEmpty) {
      fail('需显式 TEST_EXPECTED_UID、PEER_UID、PEER_TITLE');
    }
    if (!requireBusinessWriteAuthorization()) return;
    await ensureAppLaunched(tester, maxSeconds: 3);
    if (!await checkPreconditions(tester)) {
      fail('J18.e 前置失败：登录未进入主界面');
    }
    final actualUid = UserRepoLocal.to.currentUid;
    if (actualUid != _expectedUid || actualUid == _peerUid) {
      fail('登录账号 UID=$actualUid 与授权发送方 $_expectedUid 不一致');
    }
    await settle(tester, maxSeconds: 2);
    await dismissRecoveryGuide(tester);
    await settle(tester, maxSeconds: 2);

    if (!await _openConversationTab(tester)) {
      fail('无法进入会话列表');
    }
    await settle(tester, maxSeconds: 2);

    final peerItem = find.byWidgetPredicate(
      (widget) =>
          widget is ConversationItem &&
          widget.model.type == 'C2C' &&
          widget.model.peerId.toString() == _peerUid &&
          widget.model.resolvedTitle == _peerTitle,
    );
    if (!tester.any(peerItem)) {
      fail('会话列表中无目标 $_peerTitle (uid=$_peerUid) 的 C2C 会话');
    }
    await safeTap(tester, peerItem.first);
    await settle(tester, maxSeconds: 3);
    final chatPage = find.byType(ChatPage);
    expect(chatPage, findsOneWidget, reason: '应进入聊天页');
    expect(
      tester.widget<ChatPage>(chatPage).peerId,
      _peerUid,
      reason: '聊天对象必须等于授权目标',
    );

    // 历史窗口内的已加载填充消息（首启离线拉取窗口可能是最近 10 条）。
    // 动态选择其中最旧（编号最小）的一条作为引用目标：它离底部最远、
    // 发送后自动回底时必然在视口之外。等待历史同步最多 20s。
    final loaded = <int>[];
    var waited = 0;
    while (loaded.length < 4 && waited < 20) {
      loaded.clear();
      for (var n = 1; n <= 20; n++) {
        final tag = 'J18E 填充消息 #${n.toString().padLeft(2, '0')}';
        if (tester.any(find.textContaining(tag, findRichText: true))) {
          loaded.add(n);
        }
      }
      if (loaded.length < 4) {
        await settle(tester, maxSeconds: 2);
        waited += 2;
      }
    }
    if (loaded.isEmpty) {
      final rich = find.textContaining('J18E 填充消息', findRichText: true);
      debugPrint('J18E-DIAG loadedEmpty richCount=${rich.evaluate().length}');
      await takeScreenshot(tester, 'j18e_00_diag_no_filler');
      fail('历史窗口 20s 内未加载任何填充消息，fixture 不满足');
    }
    final targetNo = loaded.first;
    final targetTag = 'J18E 填充消息 #${targetNo.toString().padLeft(2, '0')}';
    final targetBubble = find.textContaining(targetTag, findRichText: true);

    // 滚到该消息使其可见，长按 → 「引用」。
    await tester.scrollUntilVisible(
      targetBubble.first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, maxSeconds: 2);
    await tester.longPress(targetBubble.first);
    await settle(tester, maxSeconds: 2);

    final quoteAction = find.text('引用');
    if (!tester.any(quoteAction)) {
      fail('长按菜单中未找到「引用」动作');
    }
    await safeTap(tester, quoteAction.first);
    await settle(tester, maxSeconds: 2);

    // 输入 marker 并经真实发送链发出（发送后列表自动回底）。
    final marker = '$_markerPrefix ${DateTime.now().millisecondsSinceEpoch}';
    final input = find.descendant(
      of: chatPage,
      matching: find.byType(CupertinoTextField),
    );
    if (!tester.any(input)) {
      fail('聊天页无输入框');
    }
    await tester.enterText(input.first, marker);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 100));
    final sent = await tapAny(tester, [
      find.byKey(const ValueKey('send_button_inner')),
      find.byKey(const ValueKey('send_button')),
      find.byIcon(CupertinoIcons.arrow_up),
    ]);
    if (!sent) {
      fail('未找到发送按钮，marker 未发出');
    }
    await settle(tester, maxSeconds: 3);
    expect(
      find.textContaining(marker, findRichText: true),
      findsWidgets,
      reason: '带引用消息应出现在聊天列表',
    );

    // 发送后列表回底：此时目标气泡在视口之外，屏幕上只有「我」的
    // 引用条预览含 #05 文本。预览 = 纵向位置最靠下的匹配项。
    final previewFinder = find.textContaining(targetTag, findRichText: true);
    final topsBefore = _topsOf(tester, previewFinder);
    if (topsBefore.isEmpty) {
      fail('发送后引用条预览未找到 $targetTag 文本');
    }
    final previewTop = topsBefore.reduce((a, b) => a > b ? a : b);

    // 对最下方的匹配项（引用条预览）按坐标点按其中心。
    var tapped = false;
    for (final element in previewFinder.evaluate()) {
      final ro = element.renderObject;
      if (ro is RenderBox && ro.hasSize && ro.attached) {
        final dy = ro.localToGlobal(Offset.zero).dy;
        if ((dy - previewTop).abs() < 2) {
          await tester.tapAt(ro.localToGlobal(ro.size.center(Offset.zero)));
          tapped = true;
          break;
        }
      }
    }
    expect(tapped, isTrue, reason: '应能点中最下方的引用条预览');
    // 滚动动画 250ms + 定位重试窗口（最多约 1.5s），留足余量。
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    await settle(tester, maxSeconds: 5);

    // oracle：目标滚入视口，或给出可行动失败提示。二选一。
    final topsAfter = _topsOf(tester, previewFinder);
    final targetVisible = topsAfter.any((top) => top < previewTop - 80);
    if (!targetVisible) {
      expect(
        tester.any(find.text('引用的消息不可用')),
        isTrue,
        reason:
            '点击引用条后目标气泡未滚入视口（预览 top=$previewTop，'
            '点击后 tops=$topsAfter），也未出现可行动失败提示',
      );
    }
    await takeScreenshot(tester, 'j18e_01_after_quote_tap');
    drainKnownFrameworkExceptions(tester);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
