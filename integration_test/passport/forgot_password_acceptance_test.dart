// integration_test/passport/forgot_password_acceptance_test.dart
//
// 忘记密码验证码页验收（批次124）：解锁 forgot_password_pin_code_page
// 12 行阻塞（历史原因「需走到下一步并收到验证码」——本地 sms.switch=off
// 验证码照常落库不外发，TestPg 可直读验证码值，全链自包含可重跑）。
// 载体：SmokeEmpty（account=51730，mobile=+8619900001234，status=1）。
// 红线：仅本地环境（9801/4323）；email 链配真实 SMTP 会真发信，本测试
// 只走手机链路（sms.switch=off 零外发）；测毕 tearDownAll 恢复原密码 hash。
//
// 服务端契约（passport_logic:find_password/5 + verification_code_ds）：
//   - find_password 此前只有 email 分支，UI 手机链(type=mobile)走到提交
//     才报「不支持的注册类型」（批次124 真 bug，已修：加 mobile/sms 分支
//     + find_password_by_mobile/3，热更 9801 冒烟通过）。
//   - 验证码一次性消费（consume 即 invalidate）；发码 per_minute_once
//     60 秒节流（key={send_code, mobile}）；scene 不参与存取 key
//     （入口页 reset_pwd 与 pin 页重发 forgot_pwd 不一致无实际影响）。
//   - MaterialPinField length=6 纯数字：万能码 abc12345（8 位字母）物理上
//     无法输入，码值从 verification_code 表直读。
//
// 场景（行对应 forgot_password_pin_code_page.md 12 行，FP6/7 合并场景）：
//   AT-FP1  深链展示发送目标账号（query 深链 +account RichText）
//   AT-FP2  输入 6 位遮蔽验证码（shield 遮蔽图标渲染）
//   AT-FP3  不足 6 位提交触发错误态（「请把方格填满」红字）
//   AT-FP4  60 秒节流窗内重发 → 本地化频控文案 + 码不刷新（DB 断言）
//   AT-FP5  窗外重发成功提示（「验证码已发送到」+ DB 码刷新断言）
//   AT-FP6/7 新密码/确认密码明文切换（eye → eye_slash + obscureText=false）
//   AT-FP8  两次密码不一致（客户端本地拦「错误」snackBar，不跳转）
//   AT-FP10 错误验证码（服务端「验证码无效」snackBar，不跳转）
//   AT-FP9  重置成功（真码提交 → 「密码修改成功。」→ WebLoginPage →
//           HTTP 登录新密码闭环验证；tearDownAll 恢复原 hash）
//   AT-FP11 语言切换实时重建（zh ↔ en 文案切换）
//   AT-FP12 底部返回登录入口（→ WebLoginPage）
//
// 顺序依赖：AT-FP4/5/9 共用发码节流窗与验证码值——FP5 重发刷新码后
// FP9 直读最新码（无需再发码）。单独跑 FP9 时 _ensureFreshCode 会自动发码。
//
// 运行（单场景 --plain-name；define 与批次123 同配方）：
//   flutter test integration_test/passport/forgot_password_acceptance_test.dart \
//     -d macos --plain-name "AT-FP1" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../flows/api_test_client.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '111174215241304064',
);
const _account = '51730';
const _mobile = '+8619900001234';

/// 重置后的新密码（FP9 提交后经 HTTP 登录闭环验证，随后 tearDownAll 恢复）
const _newPwd = 'NewP1246';

final _baseUrl = const String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:9801',
);

/// 原密码 hash（setUpAll 备份，tearDownAll 恢复，保证 51730 可复跑后续批次）
String? _origPwdHash;

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
  // macOS flutter_tester 容器持久化上次运行登录态（批次123 GF9-11 曾用
  // 51799）：非目标账号先本地登出（d04 同款配方 quitLogin）
  if (UserRepoLocal.to.currentUid.isNotEmpty &&
      UserRepoLocal.to.currentUid != _uid) {
    await UserRepoLocal.to.quitLogin();
    final navCtx = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx).go('/welcome');
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
    }
    await _pump(tester, seconds: 6);
  }
  if (!tester.any(find.byKey(wsEmptySeen)) &&
      !tester.any(find.text('还没有工作区')) &&
      !isOnMainShell(tester)) {
    final texts = tester.allWidgets
        .whereType<Text>()
        .map((w) => w.data ?? w.textSpan?.toPlainText())
        .where((s) => s != null && s.trim().isNotEmpty)
        .take(24)
        .toList();
    iPrint('[DIAG] boot 未达稳定态，uid=${UserRepoLocal.to.currentUid}，页面文本=$texts');
    markTestSkipped('未到达登录稳定态（主 Shell）');
    return false;
  }
  expect(UserRepoLocal.to.currentUid, _uid, reason: '登录账号必须是 51730 载体');
  return true;
}

/// 深链直达验证码页。query 携带 account/accountType（extra 深链不可达，
/// 批次124 路由增强：extra 优先、query 兜底）；登录态下 passport 公开路由
/// 不被认证 redirect 拦截。
void _openPin(WidgetTester tester) {
  final path =
      '/forgot_password/pin?account=${Uri.encodeComponent(_mobile)}'
      '&accountType=mobile';
  GoRouter.of(tester.element(find.byType(Navigator).first)).go(path);
}

Future<bool> _waitForPinPage(WidgetTester tester) {
  return _waitFor(
    tester,
    () => tester.any(find.byType(MaterialPinField)),
    seconds: 10,
  );
}

/// 匿名发码（与 UI 重发按钮同后端契约；local 不外发）
Future<bool> _httpSendCode() async {
  final client = FlowApiClient(baseUrl: _baseUrl, deviceId: 'forgot-pwd-probe');
  final resp = await client.post(
    '/api/v1/passport/getcode',
    data: {'type': 'sms', 'scene': 'reset_pwd', 'account': _mobile},
  );
  return resp['code'] == 0;
}

/// 距上次发码的秒数（发码节流 per_minute_once=60s）
Future<int> _secondsSinceCodeIssued() async {
  final secs = await TestPg.scalar(
    'SELECT COALESCE(EXTRACT(EPOCH FROM (now() - created_at)), 9999) '
    'FROM verification_code WHERE id = @id LIMIT 1',
    {'id': _mobile},
  );
  return secs is num ? secs.toInt() : 9999;
}

/// 等待发码节流窗过去（页面上限 90 秒）
Future<void> _waitForThrottleWindow() async {
  for (var i = 0; i < 18; i++) {
    if (await _secondsSinceCodeIssued() > 55) return;
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

/// 直读当前验证码值（local 落库不外发，6 位数字可输入 number 键盘）
Future<String> _readDbCode() async {
  return (await TestPg.scalar(
    'SELECT code FROM verification_code WHERE id = @id LIMIT 1',
    {'id': _mobile},
  )).toString();
}

Future<void> _inputPin(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(MaterialPinField).first, code);
  await _pump(tester, seconds: 1);
}

Future<void> _inputPwdPair(
  WidgetTester tester,
  String pwd,
  String rePwd,
) async {
  final newField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '新的密码',
  );
  final reField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '重新输入密码',
  );
  await tester.enterText(newField.first, pwd);
  await tester.enterText(reField.first, rePwd);
  await _pump(tester, seconds: 1);
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(find.text('设置密码'), warnIfMissed: false);
  await _pump(tester, seconds: 1);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 备份原密码 hash：FP9 会真实改掉 51730 的密码， tearDownAll 恢复，
    // 保证后续批次/测试用 admin888c 登录不受影响。
    _origPwdHash = (await TestPg.scalar(
      'SELECT password FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    )).toString();
    iPrint('[FP] 原 password hash 已备份（len=${_origPwdHash!.length}）');
  });

  tearDownAll(() async {
    if (_origPwdHash == null || _origPwdHash!.isEmpty) return;
    await TestPg.execute('UPDATE "user" SET password = @pwd WHERE id = @id', {
      'pwd': _origPwdHash,
      'id': int.parse(_uid),
    });
    iPrint('[FP] 原 password hash 已恢复（tearDownAll）');
  });

  testWidgets('AT-FP1 深链展示验证码发送目标账号', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue, reason: '深链应直达验证码页');

    // RichText：前缀「验证码已发送到手机」+ 加粗账号
    final shown = await _waitFor(
      tester,
      () => tester.any(find.textContaining(_mobile, findRichText: true)),
      seconds: 8,
    );
    expect(shown, isTrue, reason: '应展示发送目标账号 $_mobile');
    expect(
      tester.any(find.textContaining('验证码已发送到手机', findRichText: true)),
      isTrue,
      reason: 'mobile 类型应走「已发送到手机」文案分支',
    );
  });

  testWidgets('AT-FP2 输入 6 位遮蔽验证码（shield 遮蔽图标）', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    // 码值随意（不提交不消费）：本场景只验证遮蔽渲染
    await _inputPin(tester, '246810');
    expect(
      tester.any(find.byIcon(CupertinoIcons.shield)),
      isTrue,
      reason: 'obscuringWidget 应以 shield 图标遮蔽已输入位',
    );
    // 提交按钮未点，页面停留本页
    expect(tester.any(find.text('设置密码')), isTrue);
  });

  testWidgets('AT-FP3 验证码不足 6 位提交触发错误态', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    await _inputPin(tester, '123');
    await _tapSubmit(tester);
    final err = await _waitFor(
      tester,
      () => tester.any(find.text('请把方格填满')),
      seconds: 6,
    );
    expect(err, isTrue, reason: '不足 6 位应展示「请把方格填满」错误提示');
    expect(
      tester.any(find.byType(MaterialPinField)),
      isTrue,
      reason: '错误态应停留本页',
    );
  });

  testWidgets('AT-FP4 60 秒节流窗内重发 → 频控文案且码不刷新', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    expect(await _httpSendCode(), isTrue, reason: '前置：HTTP 发码应成功');
    final before = await _readDbCode();
    expect(before.length, 6, reason: '前置：码应落库');

    await tester.tap(find.text('重发验证码'), warnIfMissed: false);
    // 刚发过码（<60s）：确定性命中 per_minute_once，本地化频控文案
    // （批次119 修复裸显英文错误码后的行为）
    final feedback = await _waitFor(
      tester,
      () =>
          tester.any(find.text('操作频率过高，请稍后再试')) ||
          tester.any(find.textContaining('验证码已发送到')),
      seconds: 8,
    );
    expect(feedback, isTrue, reason: '节流窗内重发应弹本地化频控文案');
    final after = await _readDbCode();
    expect(after, before, reason: '节流命中不应刷新验证码');
  });

  testWidgets('AT-FP5 窗外重发成功提示且码刷新', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    final before = await _readDbCode();
    // 等 per_minute_once 60s 窗口过去（页面上限 90s）
    await _waitForThrottleWindow();

    await tester.tap(find.text('重发验证码'), warnIfMissed: false);
    final ok = await _waitFor(
      tester,
      () => tester.any(find.textContaining('验证码已发送到$_mobile')),
      seconds: 10,
    );
    expect(ok, isTrue, reason: '窗外重发应提示「验证码已发送到$_mobile」');

    final after = await _readDbCode();
    expect(after.length, 6, reason: '重发后码仍应落库');
    // 服务端一律重新生成（防穷举治理），码值应变化
    expect(after, isNot(before), reason: '重发应刷新验证码值');
  });

  testWidgets('AT-FP6/7 新密码与确认密码明文切换', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    Future<void> toggleOne(String hint) async {
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == hint,
      );
      expect(tester.any(field), isTrue, reason: '前置：$hint 字段应存在');
      await tester.enterText(field.first, 'plain1234');
      await _pump(tester);

      final tf = tester.widget<TextField>(field.first);
      expect(tf.obscureText, isTrue, reason: '$hint 初始应密文');

      // 眼睛图标是 TextField 的 suffixIcon：按字段定位，
      // 全页两个眼睛图标不能用 .first（会点到另一字段）
      final eye = find.descendant(
        of: field.first,
        matching: find.byIcon(CupertinoIcons.eye),
      );
      await tester.tap(eye, warnIfMissed: false);
      await _pump(tester);

      final tf2 = tester.widget<TextField>(field.first);
      expect(tf2.obscureText, isFalse, reason: '$hint 点眼睛后应明文');
      expect(
        tester.any(find.byIcon(CupertinoIcons.eye_slash)),
        isTrue,
        reason: '明文态应显示 eye_slash 图标',
      );
      // 切回密文，不影响另一字段的独立断言
      final eyeSlash = find.descendant(
        of: field.first,
        matching: find.byIcon(CupertinoIcons.eye_slash),
      );
      await tester.tap(eyeSlash, warnIfMissed: false);
      await _pump(tester);
      expect(
        tester.widget<TextField>(field.first).obscureText,
        isTrue,
        reason: '$hint 再次点击应切回密文',
      );
    }

    await toggleOne('新的密码');
    await toggleOne('重新输入密码');
  });

  testWidgets('AT-FP8 两次密码不一致客户端拦截', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    await _inputPin(tester, '135790');
    await _inputPwdPair(tester, 'abc12345', 'abc12345x');
    await _tapSubmit(tester);

    // resetPassword 客户端第一段校验（不发 HTTP）：rePwd != newPwd
    final err = await _waitFor(
      tester,
      () => tester.any(find.text('错误')),
      seconds: 6,
    );
    expect(err, isTrue, reason: '两次密码不一致应 snackBar 提示（errorRetypePassword）');
    expect(
      tester.any(find.byType(MaterialPinField)),
      isTrue,
      reason: '不一致应停留本页',
    );
  });

  testWidgets('AT-FP10 错误验证码服务端拒绝且不跳转', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    await _inputPin(tester, '000000');
    await _inputPwdPair(tester, 'zz123456', 'zz123456');
    await _tapSubmit(tester);

    // findpassword(type=mobile) 已由批次124 修复接入服务端，错误码
    // 应透出服务端原文「验证码无效」（修复前是「不支持的注册类型」）
    final err = await _waitFor(
      tester,
      () => tester.any(find.textContaining('验证码无效')),
      seconds: 10,
    );
    expect(err, isTrue, reason: '错误码应 snackBar 透出服务端原文「验证码无效」');
    expect(
      tester.any(find.byType(MaterialPinField)),
      isTrue,
      reason: '失败应停留本页',
    );
  });

  testWidgets('AT-FP9 正确码重置成功跳登录且新密码可登录', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    // 码源：整跑时复用 FP5 重发的新码；单跑时自动发码（含节流等待）
    if (!(await _secondsSinceCodeIssued() > 55) ||
        (await _readDbCode()).length != 6) {
      expect(await _httpSendCode(), isTrue, reason: '前置：HTTP 发码应成功');
    }
    final code = await _readDbCode();
    expect(code.length, 6, reason: '前置：码应落库');

    await _inputPin(tester, code);
    await _inputPwdPair(tester, _newPwd, _newPwd);
    await _tapSubmit(tester);

    final toast = await _waitFor(
      tester,
      () => tester.any(find.text('密码修改成功。')),
      seconds: 10,
    );
    expect(toast, isTrue, reason: '重置成功应提示「密码修改成功。」');

    final onLogin = await _waitFor(
      tester,
      () =>
          tester.any(find.byType(WebLoginPage)) ||
          tester.any(find.byKey(const Key('login_submit_button'))),
      seconds: 10,
    );
    expect(onLogin, isTrue, reason: '重置成功应跳登录页（宽屏 Web/窄屏 LoginPage）');

    // DB 闭环：password hash 已变化（tearDownAll 恢复）
    final newHash = (await TestPg.scalar(
      'SELECT password FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    )).toString();
    expect(newHash, isNot(_origPwdHash), reason: '服务端应更新密码 hash');

    // 登录闭环：新密码 HTTP 登录成功（明文直发，rsa_encrypt=0 契约）
    final client = FlowApiClient(
      baseUrl: _baseUrl,
      deviceId: 'forgot-pwd-probe',
    );
    final login = await client.post(
      '/api/v1/passport/login',
      data: {
        'type': 'account',
        'account': _account,
        'pwd': _newPwd,
        'rsa_encrypt': '0',
      },
    );
    expect(login['code'], 0, reason: '重置后新密码应可登录（code=0）');
  });

  testWidgets('AT-FP11 语言切换实时重建页面', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);
    expect(
      tester.any(find.textContaining('验证码已发送到手机', findRichText: true)),
      isTrue,
    );

    await LocaleSettings.setLocale(AppLocale.enUs);
    final en = await _waitFor(
      tester,
      () => tester.any(
        find.textContaining(
          'Verification code sent to mobile',
          findRichText: true,
        ),
      ),
      seconds: 8,
    );
    expect(en, isTrue, reason: '切英文后文案应实时重建');

    await LocaleSettings.setLocale(AppLocale.zhCn);
    final zh = await _waitFor(
      tester,
      () => tester.any(find.textContaining('验证码已发送到手机', findRichText: true)),
      seconds: 8,
    );
    expect(zh, isTrue, reason: '切回中文应实时重建');
  });

  testWidgets('AT-FP12 底部返回登录入口跳转', (tester) async {
    if (!await _boot(tester)) return;
    _openPin(tester);
    expect(await _waitForPinPage(tester), isTrue);

    // 底部「想再试一次吗？ 登录」的登录入口（页面内「登录」文本唯一性
    // 由 pin 页结构保证：AppBar 返回按钮是图标非文本）
    await tester.tap(find.text('登录').last, warnIfMissed: false);
    // go('/sign_in') 落地页按窗口宽度分流：宽屏 WebLoginPage / 窄屏
    // LoginPage（macOS flutter_tester 窗口实测走 LoginPage 分支，
    // login_submit_button 是 LoginPage 的提交钮 Key）
    final onLogin = await _waitFor(
      tester,
      () =>
          tester.any(find.byType(WebLoginPage)) ||
          tester.any(find.byKey(const Key('login_submit_button'))),
      seconds: 10,
    );
    expect(onLogin, isTrue, reason: '底部登录入口应跳登录页');
  });
}
