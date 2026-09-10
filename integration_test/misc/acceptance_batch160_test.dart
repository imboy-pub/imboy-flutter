// integration_test/misc/acceptance_batch160_test.dart
//
// 批次160（automation 第三十三轮）：3 行阻塞解锁。
//   AT-MN1   chat_page「群内 @成员与 @所有人拦截」：载体 smoke_bob 在
//            产品研发群(110610282598107136) role=1（普通成员，DB 实证）。
//            打 '@' 弹提及列表 → 断言成员候选存在且【所有人】选项不出现
//            （非 admin UI 层即拦截，mention_list_widget isAdmin 门）；
//            点选成员 → 输入框插入 @昵称。
//   AT-SUL10 signup_continue「语言切换实时重建」：批次119/146 沙盒注码
//            口径——getcode(sms signup) 落库不外发，码从 TestPg 直读，
//            setSignupData 注入后 push /sign_up/continue；页内切
//            zh↔en 断言文案实时重建（页 L48-77 locale stream 监听）。
//            全程不提交注册，不产生账号。
//   AT-QR1   quick_reply_manage「未登录态隐藏新增按钮」：quitLogin 后
//            直接 Navigator.push 页面（无路由注册，批次159 实证 push 法
//            可行），_uid.isEmpty → FAB 为 SizedBox.shrink + 空态文案。
//
// 运行（define 与批次159 同配方）：
//   flutter test integration_test/misc/acceptance_batch160_test.dart -d macos \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=smoke_bob --dart-define=TEST_PASSWORD=admin888 \
//     --dart-define=TEST_EXPECTED_UID=1000000056 \
//     --dart-define=TEST_ALLOW_WORKSPACE_ACCEPTANCE=true

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/chat/mention_list_widget.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat/widget/quick_reply_manage_page.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '1000000056',
);
// 产品研发群：bob role=1 普通成员（DB 实证，@所有人拦截载体）
const _groupId = '110610282598107136';
// signup 语言切换载体手机号（未注册过，发码落库不外发）
const _suMobile = '+861990001235';
const _suPwd = 'Abc123456';
const _suNickname = 'AT160L';

final _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:9801',
);

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

/// 打开会话页并等待输入框就绪（含回锚重试，批次159 配方）
Future<void> _openChat(WidgetTester tester, String peerId, String type) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  var onChat = false;
  for (var attempt = 1; attempt <= 3 && !onChat; attempt++) {
    router.go('/chat/$peerId?type=$type');
    onChat = await _waitFor(
      tester,
      () => tester.any(find.byKey(const Key('chat_message_input'))),
      seconds: 12,
    );
    if (!onChat) {
      router.go('/bottom_navigation');
      await _pump(tester, seconds: 4);
    }
  }
  expect(onChat, isTrue, reason: '前置：会话页可达（peer=$peerId）');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-MN1 群内 @成员与 @所有人拦截', (tester) async {
    if (!await _boot(tester)) return;
    await _openChat(tester, _groupId, 'C2G');

    final input = find.byKey(const Key('chat_message_input'));
    await tester.enterText(input, '');
    await _pump(tester, seconds: 1);

    // 打 '@' 触发提及列表
    await tester.enterText(input, '@');
    final listShown = await _waitFor(
      tester,
      () => tester.any(find.byType(MentionListWidget)),
      seconds: 8,
    );
    expect(listShown, isTrue, reason: '前置：输入 @ 应弹出提及列表');

    // 非管理员拦截：@所有人 选项不应出现（mention_list_widget isAdmin 门）
    final rowTexts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(MentionListWidget),
            matching: find.byType(Text),
          ),
        )
        .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
        .where((s) => s.trim().isNotEmpty)
        .toSet();
    flowLog('[诊断] 提及候选=$rowTexts');
    expect(
      rowTexts.any((s) => s.contains('所有人')),
      isFalse,
      reason: '普通成员(role=1)的提及列表不应出现「所有人」选项（UI 层拦截）',
    );
    // @成员：点选列表中的成员行，输入框应插入 @昵称
    final memberTexts = rowTexts
        .where((s) => s != '@' && s.isNotEmpty && !s.startsWith('@'))
        .toList();
    expect(memberTexts, isNotEmpty, reason: '前置：候选列表应含群成员');
    final picked = memberTexts.first;
    final row = find.descendant(
      of: find.byType(MentionListWidget),
      matching: find.text(picked),
    );
    await tester.tap(row.first, warnIfMissed: false);
    await _pump(tester, seconds: 1);

    final tf = tester.widget<CupertinoTextField>(input);
    expect(
      tf.controller?.text.contains(picked),
      isTrue,
      reason: '点选成员后输入框应插入 @$picked',
    );
    // 清空，避免残留文本误触发发送
    await tester.enterText(input, '');
    await _pump(tester, seconds: 1);
    flowLog('[AT-MN1] PASS：@成员插入 + @所有人成员侧不出现');
  });

  testWidgets('AT-SUL10 signup_continue 语言切换实时重建', (tester) async {
    if (!await _boot(tester)) return;

    // 沙盒注码：getcode 落库不外发；重跑 60s 频控内直接复用现有码
    var code = '';
    final existing = await TestPg.scalar(
      "SELECT code || ',' || EXTRACT(EPOCH FROM (now() - created_at))::int "
      'FROM verification_code WHERE id = @_id LIMIT 1',
      {'_id': _suMobile},
    );
    if (existing != null && '$existing'.isNotEmpty) {
      final parts = '$existing'.split(',');
      if (parts.length == 2 && int.tryParse(parts[1]) != null) {
        final age = int.parse(parts[1]);
        if (age < 55) code = parts[0];
      }
    }
    if (code.isEmpty) {
      final client = FlowApiClient(baseUrl: _baseUrl, deviceId: 'batch160-su');
      final resp = await client.post(
        '/api/v1/passport/getcode',
        data: {'type': 'sms', 'scene': 'signup', 'account': _suMobile},
      );
      expect(resp['code'], 0, reason: '前置：getcode(sms signup) 应成功');
      for (var i = 0; i < 10 && code.isEmpty; i++) {
        await _pump(tester, seconds: 1);
        final c = await TestPg.scalar(
          'SELECT code FROM verification_code WHERE id = @_id LIMIT 1',
          {'_id': _suMobile},
        );
        if (c != null && '$c'.length == 6) code = '$c';
      }
    }
    expect(code.length, 6, reason: '前置：验证码应落库可读（sms off 口径）');
    flowLog('[诊断] signup 码已取得（长度 6）');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    container
        .read(passportProvider.notifier)
        .setSignupData(
          account: _suMobile,
          accountType: 'mobile',
          password: _suPwd,
          nickname: _suNickname,
        );
    final router = GoRouter.of(tester.element(find.byType(Navigator).first));
    router.push('/sign_up/continue');
    final zhShown = await _waitFor(
      tester,
      () => tester.any(find.text('重发验证码')),
      seconds: 10,
    );
    expect(zhShown, isTrue, reason: '前置：注册继续页应展示中文文案');

    // 页内切英文 → 文案实时重建（locale stream → setState）
    await LocaleSettings.setLocale(AppLocale.enUs);
    final enShown = await _waitFor(
      tester,
      () => tester.any(find.text('Resend verification code')),
      seconds: 8,
    );
    expect(enShown, isTrue, reason: '切英文后「重发验证码」应实时变英文');

    await LocaleSettings.setLocale(AppLocale.zhCn);
    final zhBack = await _waitFor(
      tester,
      () => tester.any(find.text('重发验证码')),
      seconds: 8,
    );
    expect(zhBack, isTrue, reason: '切回中文应实时重建');

    // 不提交注册（零账号产生）；注入数据由页面 dispose 自清
    flowLog('[AT-SUL10] PASS：注册继续页 zh↔en 实时重建');
  });

  testWidgets('AT-QR1 未登录态隐藏快捷回复新增按钮', (tester) async {
    if (!await _boot(tester)) return;

    // 登出后直接推页面（quick_reply_manage 无路由注册，批次159 实证 push 法）
    await UserRepoLocal.to.quitLogin();
    await _pump(tester, seconds: 4);
    expect(UserRepoLocal.to.currentUid, '', reason: '前置：应处于未登录态');

    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(
      CupertinoPageRoute<void>(
        builder: (_) => const QuickReplyManagePage(defaults: <String>[]),
      ),
    );
    await _pump(tester, seconds: 3);

    final emptyShown = await _waitFor(
      tester,
      () => tester.any(find.text('暂无快捷回复，点击右下角添加')),
      seconds: 8,
    );
    expect(emptyShown, isTrue, reason: '前置：空态文案应展示');

    expect(
      tester.any(find.byIcon(CupertinoIcons.add)),
      isFalse,
      reason: '未登录态新增 FAB 应隐藏（_uid.isEmpty → SizedBox.shrink）',
    );
    flowLog('[AT-QR1] PASS：未登录 FAB 隐藏 + 空态文案');
  });
}
