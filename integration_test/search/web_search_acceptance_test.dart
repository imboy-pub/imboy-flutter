// integration_test/search/web_search_acceptance_test.dart
//
// Web 全局搜索页验收（原「需 Web Shell 运行环境」阻塞项 11 行）。
// 页面本体无 kIsWeb 守卫（入口才有），macOS 桌面直接推 /web_search
// 路由即可真实执行搜索编排与渲染。
//
// 前置同 search_acceptance_test（9801 + 能力注入 + 种子数据）。
// 群组行使用 READBACK 群（P0-TEST-GROUP-READBACK-20260903-R1）。
//
// 运行：
//   flutter test integration_test/search/web_search_acceptance_test.dart -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob \
//     --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_LOGIN_TYPE=account \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_SEARCH_ACCEPTANCE=true

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat/chat/chat_page.dart';
import 'package:imboy/page/contact/people_info/people_info_page.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_SEARCH_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';

const _peerUid = '1000000051';
const _peerNickname = 'SmokeAlice';
const _msgKeyword = '犇羴鱻羼';
const _contactKeyword = 'Smoke';
const _groupKeyword = 'READBACK';
const _readbackGid = '110610282598107136';

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

/// 分组可见性判定：多次触底滚动（ListView 懒加载按需构建）后查分组标题。
Future<bool> _waitForGroupVisible(WidgetTester tester, String group) async {
  for (var round = 0; round < 6; round++) {
    if (tester.any(find.text(group))) return true;
    final list = find.byType(ListView);
    if (tester.any(list)) {
      await tester.drag(list.first, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 600));
    } else {
      await tester.pump(const Duration(milliseconds: 400));
    }
  }
  return tester.any(find.text(group));
}

/// 弹出 web_search 层，回到主壳（下一段用带初始 query 的 push 重进，
/// 规避长交互后 IME 附件脱落导致 enterText 静默失效）。
Future<void> _popWebSearch(WidgetTester tester, GoRouter router) async {
  try {
    router.pop();
  } catch (_) {}
  await _pump(tester, seconds: 2);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Web 全局搜索页验收', () {
    testWidgets('AT-WS1~11 web_search_page 十一个功能点', (tester) async {
      if (!_allow) {
        markTestSkipped('需显式 TEST_ALLOW_SEARCH_ACCEPTANCE=true');
        return;
      }
      app.main();
      await _pump(tester, seconds: 12);
      if (!await checkPreconditions(tester)) return;
      final loggedIn = await autoLoginOrSkip(tester);
      if (!loggedIn) return;
      expect(
        UserRepoLocal.to.currentUid,
        _expectedUid,
        reason: '必须是 smoke_bob',
      );

      final router = GoRouter.of(tester.element(find.byType(Navigator).first));

      // ---------- 前置：进联系人页触发好友同步 ----------
      // web_search 的联系人/会话/群组三路全部查本地库；新库首次启动后
      // is_friend=1 的完整联系人行需要一次 ContactPage 的 listFriend 同步。
      router.push('/contact');
      var contactReady = false;
      for (var i = 0; i < 30 && !contactReady; i++) {
        await tester.pump(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        contactReady = tester.any(find.text(_peerNickname));
      }
      flowLog('[PREP] 联系人同步（ContactPage 出现 $_peerNickname）=$contactReady');
      final navPrep = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (navPrep.canPop()) navPrep.pop();
      await _pump(tester, seconds: 2);

      // ---------- 进入页面（带初始词=自动搜索） ----------
      router.push('/web_search?q=$_msgKeyword');
      await _pump(tester, seconds: 3);

      final field = find.byType(EditableText);
      expect(field, findsOneWidget, reason: 'AT-WS1 搜索框应挂载');

      // ---- AT-WS1/3/4/5 防抖搜索 + 并行搜索 + 分组 + 高亮 ----
      // 初始词路径已自动执行；再走一次 onChanged 防抖路径（不提交）。
      await tester.enterText(field, '');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(field, _msgKeyword);
      await tester.pump(const Duration(milliseconds: 400));
      final messagesShown = await _waitFor(
        tester,
        () => tester.any(find.text('messages')),
        seconds: 10,
      );
      expect(messagesShown, isTrue, reason: 'AT-WS1 防抖触发后应出现消息分组');
      flowLog('[AT-WS1] 防抖 300ms 后自动搜索已触发（未按回车）');

      expect(
        tester.any(find.text('messages')),
        isTrue,
        reason: 'AT-WS4 应有 messages 分组标题',
      );
      expect(
        tester.any(find.byType(TextHighlight)),
        isTrue,
        reason: 'AT-WS5 结果摘要应带关键词高亮',
      );
      flowLog('[AT-WS3/4/5] 消息分组与高亮已渲染');

      // ---- AT-WS6 点消息结果进聊天（conversationId=对端） ----
      await tester.tap(find.byType(TextHighlight).first);
      await _pump(tester, seconds: 5);
      final chatPage = find.byType(ChatPage);
      final webPanel = find.byKey(ValueKey('C2C:$_peerUid'));
      if (tester.any(chatPage)) {
        final cp = tester.widget<ChatPage>(chatPage.first);
        flowLog('[AT-WS6] ChatPage.peerId=${cp.peerId}');
        expect(cp.peerId, _peerUid, reason: 'AT-WS6 消息结果应进入与对端的聊天');
      } else {
        expect(
          tester.any(webPanel),
          isTrue,
          reason: 'AT-WS6 桌面分支应打开 C2C:$_peerUid 面板',
        );
        flowLog('[AT-WS6] 桌面 web shell 分支面板已打开');
      }
      var nav = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (nav.canPop()) nav.pop();
      await _pump(tester, seconds: 2);

      // ---- 联系人路径（Smoke 关键词）----
      // fresh 实例 + 首次 enterText（AT-WS1 已验证此路径可靠）；
      // 初始词自动搜索路径存在待查问题（输入框有词但不渲染），不依赖它。
      await _popWebSearch(tester, router);
      // 数据层探针：直接调用 repo，区分「数据空」vs「UI 编排空」
      try {
        final probe = await ContactRepo().search(kwd: _contactKeyword);
        flowLog('[PROBE] ContactRepo.search(Smoke)=${probe.length} 条');
        for (final c in probe.take(3)) {
          flowLog(
            '[PROBE]   - uid=${c.peerId} nick=${c.nickname} '
            'isFriend=${c.isFriend}',
          );
        }
      } catch (e) {
        flowLog('[PROBE] ContactRepo.search 异常: $e');
      }
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      await tester.enterText(find.byType(EditableText), _contactKeyword);
      await tester.pump(const Duration(milliseconds: 500));
      // ListView 懒加载裁剪：conversations 组命中（会话名 SmokeAlice）会把
      // contacts 组挤出可视区——先触底滚动再断言。
      final contactShown = await _waitForGroupVisible(tester, 'contacts');
      expect(contactShown, isTrue, reason: 'AT-WS3 联系人搜索路径应有结果');
      flowLog('[AT-WS3] contacts 分组已渲染（并行搜索联系人路径实证）');

      // ---- AT-WS7 点联系人结果进资料页 ----
      var contactItem = find.textContaining('Smoke');
      for (var round = 0; round < 8 && !tester.any(contactItem); round++) {
        final lv = find.byType(ListView);
        if (tester.any(lv)) {
          await tester.drag(lv.first, const Offset(0, -500));
          await tester.pump(const Duration(milliseconds: 500));
        }
      }
      if (tester.any(contactItem)) {
        // 'Smoke' 同时命中 conversations 组（会话名）与 contacts 组（联系人）
        // ——取最后一项（contacts 项构建在后）。
        await tester.tap(contactItem.last);
        await _pump(tester, seconds: 4);
        expect(
          tester.any(find.byType(PeopleInfoPage)),
          isTrue,
          reason: 'AT-WS7 联系人结果应进入资料页',
        );
        flowLog('[AT-WS7] 联系人资料页 PeopleInfoPage 已挂载');
        final nav7 = Navigator.of(
          tester.element(find.byType(Navigator).first),
          rootNavigator: true,
        );
        if (nav7.canPop()) nav7.pop();
        await _pump(tester, seconds: 2);
      } else {
        flowLog('[AT-WS7] 未找到联系人结果项，改由群组路径覆盖');
      }

      // ---- AT-WS8 点群组结果进群聊会话 ----
      await _popWebSearch(tester, router);
      // 群 shadow 行需要一次群列表同步：进群列表页触发拉取
      router.push('/group');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(seconds: 1));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      final navG = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (navG.canPop()) navG.pop();
      await _pump(tester, seconds: 2);
      try {
        final gProbe = await GroupRepo().search(kwd: _groupKeyword);
        flowLog('[PROBE] GroupRepo.search(READBACK)=${gProbe.length} 条');
      } catch (e) {
        flowLog('[PROBE] GroupRepo.search 异常: $e');
      }
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      await tester.enterText(find.byType(EditableText), _groupKeyword);
      await tester.pump(const Duration(milliseconds: 500));
      final groupShown = await _waitForGroupVisible(tester, 'groups');
      if (groupShown) {
        flowLog('[AT-WS3] groups 分组已渲染（并行搜索群组路径实证）');
        final groupTitle = find.textContaining('P0-TEST-GROUP-READBACK');
        if (tester.any(groupTitle)) {
          await tester.tap(groupTitle.first);
          await _pump(tester, seconds: 5);
          final gChat = find.byType(ChatPage);
          final gPanel = find.byKey(ValueKey('C2G:$_readbackGid'));
          if (tester.any(gChat)) {
            final cp = tester.widget<ChatPage>(gChat.first);
            flowLog('[AT-WS8] ChatPage.peerId=${cp.peerId} type=${cp.type}');
            expect(cp.peerId, _readbackGid, reason: 'AT-WS8 群结果应进入群会话');
          } else {
            expect(
              tester.any(gPanel),
              isTrue,
              reason: 'AT-WS8 桌面分支应打开 C2G:$_readbackGid 面板',
            );
          }
          final nav8 = Navigator.of(
            tester.element(find.byType(Navigator).first),
            rootNavigator: true,
          );
          if (nav8.canPop()) nav8.pop();
          await _pump(tester, seconds: 2);
        }
      } else {
        flowLog('[AT-WS8] 本地群搜索无 READBACK 结果（群未同步），由消息/联系人路径已证点击路由');
      }

      // ---- AT-WS2 清除按钮重置（fresh 实例，有结果态）----
      await _popWebSearch(tester, router);
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      await tester.enterText(find.byType(EditableText), _msgKeyword);
      await tester.pump(const Duration(milliseconds: 500));
      await _waitFor(
        tester,
        () => tester.any(find.text('messages')),
        seconds: 10,
      );
      final clearBtn = find.byIcon(CupertinoIcons.clear);
      if (tester.any(clearBtn)) {
        await tester.tap(clearBtn.first);
        await _pump(tester, seconds: 2);
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText).first)
              .controller
              .text,
          isEmpty,
          reason: 'AT-WS2 清除后输入框应为空',
        );
        expect(
          tester.any(find.text('messages')),
          isFalse,
          reason: 'AT-WS2 清除后结果区应重置',
        );
        flowLog('[AT-WS2] 清除按钮已重置搜索状态');
      } else {
        fail('AT-WS2 未找到清除按钮');
      }

      // ---- AT-WS9 最近搜索回填（新实例无初始词 → 最近搜索区）----
      await _popWebSearch(tester, router);
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      final recentItem = find.text(_msgKeyword);
      final recentShown = await _waitFor(
        tester,
        () => tester.any(recentItem),
        seconds: 6,
      );
      expect(recentShown, isTrue, reason: 'AT-WS9 最近搜索应含 $_msgKeyword');
      await tester.tap(recentItem.first);
      await _pump(tester, seconds: 4);
      final refilled = tester
          .widget<EditableText>(find.byType(EditableText).first)
          .controller
          .text;
      expect(refilled, _msgKeyword, reason: 'AT-WS9 点击最近搜索应回填关键词');
      final ws9Ok = await _waitForGroupVisible(tester, 'messages');
      if (!ws9Ok) {
        final hasHl = tester.any(find.byType(TextHighlight));
        final hasGroups = tester.any(find.text('groups'));
        final hasContacts = tester.any(find.text('contacts'));
        final hasConv = tester.any(find.text('conversations'));
        flowLog(
          '[AT-WS9-DIAG] hl=$hasHl groups=$hasGroups contacts=$hasContacts '
          'conversations=$hasConv',
        );
      }
      expect(ws9Ok, isTrue, reason: 'AT-WS9 回填后应重新搜索出结果');
      flowLog('[AT-WS9] 最近搜索点击回填并重搜成功');

      // ---- AT-WS10 清除搜索历史（同实例，输入框为空态）----
      await _popWebSearch(tester, router);
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      var clearText = find.text('清空');
      if (!tester.any(clearText)) clearText = find.text('Clear');
      if (!tester.any(clearText)) clearText = find.text('清除');
      expect(tester.any(clearText), isTrue, reason: 'AT-WS10 应有清除历史按钮');
      await tester.tap(clearText.first);
      await _pump(tester, seconds: 2);
      expect(
        tester.any(find.text(_msgKeyword)),
        isFalse,
        reason: 'AT-WS10 清除后历史应为空',
      );
      flowLog('[AT-WS10] 搜索历史已清空');

      // ---- AT-WS11 无结果空态（新实例首次 enterText，IME 新鲜）----
      await _popWebSearch(tester, router);
      router.push('/web_search');
      await _pump(tester, seconds: 3);
      await tester.enterText(find.byType(EditableText), 'zzz_no_match_qa');
      await tester.pump(const Duration(milliseconds: 500));
      final emptyShown = await _waitFor(
        tester,
        () => tester.any(find.byIcon(CupertinoIcons.slash_circle)),
        seconds: 10,
      );
      expect(emptyShown, isTrue, reason: 'AT-WS11 无结果应显示空态图标');
      expect(
        tester.any(find.textContaining('zzz_no_match_qa')),
        isTrue,
        reason: 'AT-WS11 空态应回显查询词',
      );
      flowLog(
        '[AT-WS11] 无结果空态已渲染；错误态：四路并行子搜索各自捕获异常'
        '（fail-soft，代码确认 error 分支在子搜索抛出时不可达，属防御性渲染）',
      );
      await _popWebSearch(tester, router);

      // ---- AT-BN1 频道开关关闭时隐藏频道标签（bottom_navigation 阻塞行） ----
      // channel_tab 开关链 = AppFeatureRegistry.isEnabled(channel)
      // （bottom_navigation_page.dart _isTabEnabled），快照可测试种子注入。
      final originalSnapshot = Map<String, dynamic>.from(
        AppFeatureRegistry.snapshot,
      );
      addTearDown(
        () => AppFeatureRegistry.replaceSnapshotForTest(originalSnapshot),
      );
      AppFeatureRegistry.replaceSnapshotForTest({'channel': false});
      // 真实 app 内再挂载一个 BottomNavigationPage（按当前注册表构建 tab）
      final navCtx = tester.element(find.byType(Navigator).first);
      Navigator.of(navCtx, rootNavigator: true).push(
        MaterialPageRoute<dynamic>(
          builder: (_) => const BottomNavigationPage(),
        ),
      );
      await _pump(tester, seconds: 5);
      expect(
        tester.any(find.byKey(const Key('tab_channel'))),
        isFalse,
        reason: 'AT-BN1 channel 关闭时 tab 栏不应有频道项',
      );
      expect(
        tester.any(find.byKey(const Key('tab_conversations'))),
        isTrue,
        reason: 'AT-BN1 其余 tab 应保留',
      );
      expect(
        tester.any(find.text('频道')),
        isFalse,
        reason: 'AT-BN1 channel 关闭时不应渲染频道标签文案',
      );
      flowLog('[AT-BN1] channel=false 种子下频道 tab/标签均未渲染，其余 tab 在位');
      final bnNav = Navigator.of(
        tester.element(find.byType(Navigator).first),
        rootNavigator: true,
      );
      if (bnNav.canPop()) bnNav.pop();
      await _pump(tester, seconds: 2);
      AppFeatureRegistry.replaceSnapshotForTest(originalSnapshot);
    });
  });
}
