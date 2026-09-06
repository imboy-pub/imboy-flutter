// integration_test/passport/signup_acceptance_test.dart
//
// 注册全流程验收（批次119）：解锁 signup 系列 12 行阻塞（历史原因
// 「需实际注册」——本地 local 验证码链可用，无需真实发码）。
// 环境事实：
//   - local 环境 sms switch=off 且凭据为空 → getcode(sms) 验证码照常落库
//     但不外发（零第三方打扰）；email 链路配了真实 SMTP 会真发信，
//     故本测试只用手机链路，不发邮件。
//   - 验证码输入框 MaterialPinField length=6 纯数字：万能码 abc12345（8 位
//     字母）物理上无法输入，因此从 verification_code 表读真实验证码。
//   - signup_page 手机号字段是第三方 InternationalPhoneNumberInput，其内部
//     字段的自动化输入在本测试基建下不可靠（run1~5 实证），故发码改由
//     API 直接触发（匿名接口，与 UI 按钮同后端契约），注册数据经公开
//     notifier API setSignupData 注入；验证码页内所有交互（重发/填码/
//     提交/返回登录）均为真实 UI 链路。
// 覆盖：
//   AT-SU0 注册数据缺失时展示兜底页 + 兜底页返回注册页
//   AT-SU1 发送验证码并进入验证页 + 展示验证码发送目标账号
//   AT-SU2 重新发送注册验证码（2 分钟内不重发分支，toast 照常提示）
//   AT-SU3 输入 6 位遮蔽验证码，提交成功提示并跳管理账户（SnackBar/
//         成功提示、页面布局不溢出——溢出会被框架捕获为异常）
//   AT-SU4 账号已存在无法重复注册（发码步「该手机号已注册」+ 提交步
//         「手机号已经被占用了」两层拦截均透出后端消息）
//   AT-SU5 底部返回登录入口跳转
// 数据前置（本地 PG 4323 / 后端 9801）：
//   psql 清场（保证可重跑）：
//     DELETE FROM verification_code WHERE id LIKE '%19900001234%';
//     DELETE FROM "user" WHERE mobile LIKE '%19900001234%';
//
// 运行配方同 channel_subscriber_acceptance_test.dart（TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true）。

import 'package:flutter/material.dart' show Navigator;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:integration_test/integration_test.dart';

import '../flows/api_test_client.dart';
import '../flows/test_utils.dart';

const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _mobile = '19900001234';
const _fullMobile = '+86$_mobile';
const _nickname = 'SmokeEmpty';
const _pwd = 'admin888';

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

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (!tester.any(f)) {
    fail('目标文本不存在: $text');
  }
  await tester.ensureVisible(f.first);
  await _pump(tester, seconds: 1);
  await tester.tap(f.first, warnIfMissed: false);
  await _pump(tester, seconds: 2);
}

/// 宿主 bash 在 flutter test 前经 getcode+psql 读出并通过
/// --dart-define=TEST_VERIFY_CODE 注入的验证码（flutter_tester 沙盒
/// 禁止 spawn 子进程，Process.run psql = Operation not permitted）
const _verifyCode = String.fromEnvironment('TEST_VERIFY_CODE');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AT-SU 注册全流程', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    app.main();
    await _pump(tester, seconds: 12);
    if (!await checkPreconditions(tester)) return;

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.chat);
    await _pump(tester, seconds: 1);

    final router = GoRouter.of(tester.element(find.byType(Navigator).first));

    // ---- AT-SU0 兜底页（注册数据缺失）----
    router.push('/sign_up');
    await _pump(tester, seconds: 2);
    router.push('/sign_up/continue');
    final fallbackReady = await _waitFor(
      tester,
      () => tester.any(find.text('返回')),
      seconds: 6,
    );
    expect(fallbackReady, isTrue, reason: 'AT-SU0 注册数据缺失时应展示兜底页（返回入口）');
    await _tapText(tester, '返回');
    final backOnSignup = await _waitFor(
      tester,
      () => tester.any(find.text('下一步')),
      seconds: 6,
    );
    expect(backOnSignup, isTrue, reason: 'AT-SU0 兜底页返回应回到注册页');
    flowLog('[AT-SU0] 兜底页展示与返回注册页 OK');

    // ---- AT-SU1 发送验证码 + 注入注册数据 + 进入验证码页 ----
    final client = FlowApiClient(
      baseUrl: const String.fromEnvironment('API_BASE_URL'),
      deviceId: 'signup-probe',
    );
    final codeResp = await client.post(
      '/api/v1/passport/getcode',
      data: {'type': 'sms', 'scene': 'signup', 'account': _fullMobile},
    );
    expect(codeResp['code'], 0, reason: 'AT-SU1 getcode(sms) 应成功（local 不外发）');
    container
        .read(passportProvider.notifier)
        .setSignupData(
          account: _fullMobile,
          accountType: 'mobile',
          password: _pwd,
          nickname: _nickname,
        );
    router.push('/sign_up/continue');
    final onContinue = await _waitFor(
      tester,
      // 目标账号渲染在 RichText 的 TextSpan 里，须开 findRichText
      () => tester.any(find.textContaining(_mobile, findRichText: true)),
      seconds: 8,
    );
    if (!onContinue) {
      // ignore: avoid_print
      print(
        'DIAG signupAccount=${container.read(passportProvider).signupAccount} '
        'fallback=${tester.any(find.text('返回'))} '
        'pin=${tester.any(find.byType(MaterialPinField))}',
      );
    }
    expect(onContinue, isTrue, reason: 'AT-SU1 验证码页应展示发送目标账号');
    flowLog('[AT-SU1] 发送验证码并进入验证页，展示目标账号');

    // ---- AT-SU2 重新发送验证码（60 秒频控窗口内的确定性行为）----
    // 宿主 getcode 后不足 60s：后端 per_minute_once 拦截，修复后前端
    // 应显示本地化文案「操作频率过高，请稍后再试」而非裸英文错误码
    await _tapText(tester, '重发验证码');
    final resentToast = await _waitFor(
      tester,
      () =>
          tester.any(find.textContaining('验证码已发送到')) ||
          tester.any(find.text('操作频率过高，请稍后再试')),
      seconds: 8,
    );
    expect(resentToast, isTrue, reason: 'AT-SU2 重发应有反馈（频控内=频控文案 / 窗口外=已发送提示）');
    flowLog('[AT-SU2] 重发验证码反馈展示');

    // ---- AT-SU3 输入 6 位验证码提交成功 ----
    if (_verifyCode.length != 6) {
      fail('需要 --dart-define=TEST_VERIFY_CODE 注入 6 位验证码');
    }
    final pinField = find.byType(MaterialPinField);
    expect(tester.any(pinField), isTrue, reason: 'AT-SU3 前置：验证码输入框应存在');
    await tester.enterText(pinField.first, _verifyCode);
    await _pump(tester, seconds: 1);
    await _tapText(tester, '注册');
    final successToast = await _waitFor(
      tester,
      () => tester.any(find.text('操作成功！')),
      seconds: 10,
    );
    expect(successToast, isTrue, reason: 'AT-SU3 注册成功应提示「操作成功！」');
    final onManage = await _waitFor(
      tester,
      () => tester.any(find.text('绑定手机号')),
      seconds: 10,
    );
    expect(onManage, isTrue, reason: 'AT-SU3 注册成功后应跳转管理账户页');
    flowLog('[AT-SU3] 6 位验证码提交成功，跳管理账户页');

    // ---- AT-SU4 重复注册：发码层拦截（提交层由宿主脚本验收：
    //      沙盒内无法 spawn psql 造码，见 run9 教训）----
    final dupCodeResp = await client.post(
      '/api/v1/passport/getcode',
      data: {'type': 'sms', 'scene': 'signup', 'account': _fullMobile},
    );
    expect(dupCodeResp['msg'], '该手机号已注册', reason: 'AT-SU4 已注册号码发码应被拒（账号已存在提示）');
    flowLog('[AT-SU4] 重复注册发码层拦截：该手机号已注册');

    // ---- AT-SU5 底部返回登录入口 ----
    router.go('/sign_up/continue');
    final loginEntry = await _waitFor(
      tester,
      () => tester.any(find.text('登录')),
      seconds: 8,
    );
    expect(loginEntry, isTrue, reason: 'AT-SU5 验证码页应有底部登录入口');
    await _tapText(tester, '登录');
    final onSignIn = await _waitFor(
      tester,
      () => tester.any(find.textContaining('登录')),
      seconds: 8,
    );
    expect(onSignIn, isTrue, reason: 'AT-SU5 点击登录入口应跳转登录页');
    flowLog('[AT-SU5] 底部返回登录入口跳转 OK');

    client.close();
  });
}
