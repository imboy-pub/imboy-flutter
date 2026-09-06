// integration_test/mine/account_security_lifecycle_test.dart
//
// 账号安全生命周期验收（批次120）：解锁 mine 域 8 行「待可弃用测试账号」
// 阻塞（set_password 4 + change_password 2 + logout_account 2）。
// 载体：批次119 注册的一次性账号 SmokeEmpty（account=51730，注册密码
// admin888，手机 +8619900001234，注销终章消耗该账号）。
//
// 覆盖（五个场景按宿主编排顺序独立运行，进程间靠持久 token + PG 状态衔接）：
//   AT-AS1 设密失败兜底：已有密码时提交 set_password → 后端文案
//          「已设置过密码，请使用修改密码」透出（非通用失败文案）
//   AT-AS2 设密成功 → 未绑手机邮箱跳绑定引导页（needGuide 分支1）
//   AT-AS3 设密成功 → 已绑定时进主导航（needGuide 分支2；依赖后端
//          login_resp 补发 mobile 的修复 —— 此前登录缓存 mobile 恒空，
//          该分支对任何账号不可达）
//   AT-AS4 改密失败兜底（旧密码错误 →「密码错误」，修复前裸显
//          errorPassword 英文码）+ 改密成功（加载指示 → 成功 toast）
//   AT-AS5 注销：勾选 → 二次确认 → 服务端 apply_logout → 清理本地 →
//          欢迎页；PG 断言注销申请落库（status=2 + requested 行）
//
// 五场景运行配方（单场景用 --plain-name 选择；分场景编译 ~2min，token
// 有效期 7200s 足够）：
//   flutter test integration_test/mine/account_security_lifecycle_test.dart \
//     -d macos --plain-name "AT-AS1" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 \
//     --dart-define=TEST_PASSWORD=<当前密码> \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064 \
//     --dart-define=TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true
// 前置：后端 9801 迁移 ≥ 00000086（D-04 注销链）；本地 PG 4323。
//
// 宿主编排（/tmp/as_orchestrate.sh）按序：场景间用 psql/curl 切换
// password/email 状态并做服务端断言；终章注销消耗 SmokeEmpty。

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Navigator, TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/passport/manage_account_page.dart';
import 'package:imboy/page/welcome/welcome_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';

import 'package:imboy/page/mine/change_password/change_password_provider.dart';
import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _expectedUid = String.fromEnvironment('TEST_EXPECTED_UID');
const _allowFlag = String.fromEnvironment(
  'TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE',
  defaultValue: 'false',
);
const _allow = _allowFlag == 'true' || _allowFlag == 'True';
const _smokeUid = '111174215241304064';

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

Future<void> _go(WidgetTester tester, String path) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  router.go(path);
  await _pump(tester, seconds: 3);
}

/// set_password 页填两个密码字段并提交。
/// 字段 hint：新密码=pleaseEnterPassword、确认=retypePassword（页面内
/// 还有说明卡片同文案「密码长度…」无干扰；hintText 可被 widgetWithText
/// 命中——批次119 注册页同款用法实证）。
/// 注意：EasyLoading toast 只显示 3s，提交后不追加长 pump，
/// 让调用方的 _waitFor 首查落在显示窗口内（批次118 同款教训）。
Future<void> _fillSetPassword(WidgetTester tester, String pwd) async {
  final newField = find.widgetWithText(TextField, '请输入密码');
  final retypeField = find.widgetWithText(TextField, '重新输入密码');
  if (!tester.any(newField) || !tester.any(retypeField)) {
    fail(
      'set_password 字段缺失 new=${tester.any(newField)} retype=${tester.any(retypeField)}',
    );
  }
  await tester.enterText(newField.first, pwd);
  await _pump(tester, seconds: 1);
  await tester.enterText(retypeField.first, pwd);
  await _pump(tester, seconds: 1);
  await _tapSubmit(tester, '确认');
}

/// change_password 页填三个密码字段并提交。
Future<void> _fillChangePassword(
  WidgetTester tester,
  String oldPwd,
  String newPwd,
) async {
  // change_password 页字段是 CupertinoTextField（placeholder 承载 hint）
  final oldField = find.widgetWithText(CupertinoTextField, '请输入旧密码');
  final newField = find.widgetWithText(CupertinoTextField, '请输入新密码');
  final confirmField = find.widgetWithText(CupertinoTextField, '请再次输入新密码');
  if (!tester.any(oldField) ||
      !tester.any(newField) ||
      !tester.any(confirmField)) {
    fail(
      'change_password 字段缺失 old=${tester.any(oldField)} '
      'new=${tester.any(newField)} confirm=${tester.any(confirmField)}',
    );
  }
  await tester.enterText(oldField.first, oldPwd);
  await _pump(tester, seconds: 1);
  await tester.enterText(newField.first, newPwd);
  await _pump(tester, seconds: 1);
  await tester.enterText(confirmField.first, newPwd);
  await _pump(tester, seconds: 1);
  await _tapSubmit(tester, '保存');
}

/// 点击提交按钮后只等一帧：让 toast（3s）的消失竞速留给 _waitFor。
Future<void> _tapSubmit(WidgetTester tester, String text) async {
  final f = find.text(text);
  if (!tester.any(f)) {
    fail('提交按钮不存在: $text');
  }
  await tester.ensureVisible(f.first);
  await _pump(tester, seconds: 1);
  await tester.tap(f.first, warnIfMissed: false);
  await _pump(tester, seconds: 1);
}

Future<void> _expectSmokeUid() async {
  expect(UserRepoLocal.to.currentUid, _expectedUid, reason: '必须是 SmokeEmpty');
}

/// 会话稳定化：启动期旧 token 的并发请求会排队返回 401，其
/// http_auth_expired 回调可能在登录成功后才迟到触发（自动退登踢回
/// 登录页，连带吞掉页面 toast）。等待排空；若已被踢回登录页则重登。
Future<bool> ensureStableSession(WidgetTester tester) async {
  await _pump(tester, seconds: 8);
  for (var i = 0; i < 3; i++) {
    final onLogin =
        tester.any(find.text('登录')) || tester.any(find.byType(WelcomePage));
    if (!onLogin && UserRepoLocal.to.currentUid.isNotEmpty) return true;
    if (!await autoLoginOrSkip(tester)) return false;
    await _pump(tester, seconds: 5);
  }
  return UserRepoLocal.to.currentUid.isNotEmpty;
}

/// 启动 + 登录（带迟到 401 防御）。
/// 启动期旧 token 的并发请求会排队 401，其 http_auth_expired 回调可能在
/// 首轮登录成功后才迟到 quitLogin（清掉刚写入的会话→checkPreconditions
/// 误判「自动登录失败」）。失败时等回调排空后整体重试一轮。
Future<bool> _bootstrap(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  // 釜底抽薪：清掉上一轮残留 token（它已被服务端单设备策略失效，
  // 启动期 WS/请求风暴会用它打出 401→http_auth_expired→反复踢会话）
  try {
    if (UserRepoLocal.to.isLoggedIn) {
      await UserRepoLocal.to.quitLogin();
    }
  } catch (_) {}
  await _pump(tester, seconds: 6);
  for (var i = 0; i < 6; i++) {
    final ok0 = await checkPreconditions(tester);
    if (!ok0) {
      await _pump(tester, seconds: 6);
      continue;
    }
    await _pump(tester, seconds: 8);
    if (UserRepoLocal.to.currentUid.isNotEmpty &&
        !tester.any(find.text('登录'))) {
      return true;
    }
  }
  return false;
}

/// 真实退登 → 重登：登录响应（含修复后的 mobile 字段）刷新本地用户缓存。
/// 退登走 UserRepoLocal.quitLogin（与 setting_page _handleLogout 确认后
/// 调用的同一清理函数；设置页弹窗 UI 属批次29 已验内容，桌面双体验壳
/// 下导航不稳定，不在此重复 UI 链）。
/// [loginPwd] 必须是此刻服务端仍有效的密码（define 传入）。
Future<bool> _reloginForFreshCache(WidgetTester tester, String loginPwd) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  await UserRepoLocal.to.quitLogin();
  router.go('/welcome');
  await _pump(tester, seconds: 4);
  // checkPreconditions 内 autoLoginOrSkip：欢迎页→登录页→define 密码登录
  if (!await checkPreconditions(tester)) return false;
  if (!await ensureStableSession(tester)) return false;
  await _expectSmokeUid();
  return true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    await TestPg.close();
  });

  testWidgets('AT-AS1 设密失败兜底：已设密码透出后端文案', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrap(tester)) return;
    await _expectSmokeUid();

    // 前置自检：编排要求此刻 SmokeEmpty 已有密码（注册态 admin888）
    final hash = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    if (hash == null || hash.toString().isEmpty) {
      fail('AT-AS1 前置不满足：password 为空，请先执行编排脚本阶段0');
    }

    await _go(tester, '/set_password');
    await _fillSetPassword(tester, 'admin888s');

    // 失败路径：后端返回「已设置过密码，请使用修改密码」，
    // 修复（UserApi 错误消息本地化通道）后原样透出
    final toast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('已设置过密码')),
      seconds: 10,
    );
    if (!toast) {
      final texts = <String>{};
      for (final w in tester.widgetList(find.bySubtype<RichText>())) {
        texts.add((w as RichText).text.toPlainText());
      }
      for (final w in tester.widgetList(find.bySubtype<Text>())) {
        final t = (w as Text).data;
        if (t != null) texts.add(t);
      }
      // ignore: avoid_print
      print(
        'DIAG AS1 toast 未现，页面文本(${texts.length}): '
        '${texts.take(40).join(" | ")}',
      );
    }
    expect(toast, isTrue, reason: '应透出后端「已设置过密码」文案（非通用兜底）');

    final hashAfter = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    expect(hashAfter.toString(), hash.toString(), reason: '设密失败密码不得变化');
    await TestPg.close();
  });

  testWidgets('AT-AS2 设密成功：未绑手机邮箱跳绑定引导页', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrap(tester)) return;
    await _expectSmokeUid();

    // 前置自检：宿主保持 password 可登录 + email 已清空（编排阶段1）
    final row0 = await TestPg.execute(
      'SELECT password, email FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    final pwd0 = row0[0][0]?.toString() ?? '';
    final email0 = row0[0][1]?.toString() ?? '';
    if (pwd0.isEmpty || email0.isNotEmpty) {
      fail('AT-AS2 前置不满足：应 password 非空（可登录）+ email 空（编排阶段1）');
    }

    // 重登刷新本地缓存：持久缓存可能残留 email 非空的旧值（token 长期有效
    // 时永不刷新），必须以本次登录响应为准
    if (!await _reloginForFreshCache(tester, 'admin888s')) return;
    // 登录缓存此刻 email 为空（本次登录响应即服务端真相）
    // 重登后仍有迟到 401 风险：清密动作前再确认会话存活
    if (!await ensureStableSession(tester)) return;
    // 测试内清 password（PG 直连构造「未设密」态）
    await TestPg.execute('UPDATE "user" SET password=@p WHERE id=@id', {
      'p': '',
      'id': int.parse(_smokeUid),
    });

    await _go(tester, '/set_password');
    await _fillSetPassword(tester, 'admin888s');

    final okToast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('密码修改成功')),
      seconds: 10,
    );
    expect(okToast, isTrue, reason: '设密成功应有成功 toast');

    // email 为空 → needGuide=true → ManageAccountPage 引导页
    final guidePage = await _waitFor(
      tester,
      () => tester.any(find.byType(ManageAccountPage)),
      seconds: 10,
    );
    if (!guidePage) {
      final cu = UserRepoLocal.to.currentUser;
      // ignore: avoid_print
      print(
        'DIAG AS2 引导页未现: cacheEmail=${cu?.email} '
        'cacheMobile=${cu?.mobile} uid=${UserRepoLocal.to.currentUid}',
      );
      final texts = <String>{};
      for (final w in tester.widgetList(find.bySubtype<Text>())) {
        final t = (w as Text).data;
        if (t != null && t.isNotEmpty) texts.add(t);
      }
      // ignore: avoid_print
      print(
        'DIAG AS2 页面文本(${texts.length}): '
        '${texts.take(30).join(" | ")}',
      );
    }
    expect(guidePage, isTrue, reason: '未绑邮箱应跳绑定引导页（needGuide 分支1）');
    expect(tester.any(find.text('提升账户安全')), isTrue, reason: '引导页应渲染「提升账户安全」标题');

    final hashAfter = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    expect(hashAfter.toString().isNotEmpty, isTrue, reason: '服务端密码应已落库');
    await TestPg.close();
  });

  testWidgets('AT-AS3 设密成功：已绑定直接进主导航（mobile 修复回归）', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrap(tester)) return;
    await _expectSmokeUid();

    // 前置自检：宿主已补 email；password=admin888s（场景2 设置，可登录）
    final row = await TestPg.execute(
      'SELECT password, email, mobile FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    final pwd = row[0][0]?.toString() ?? '';
    final email = row[0][1]?.toString() ?? '';
    final mobile = row[0][2]?.toString() ?? '';
    if (pwd.isEmpty || email.isEmpty || mobile.isEmpty) {
      fail('AT-AS3 前置不满足：应 password 非空 + email/mobile 非空（编排阶段2）');
    }

    // 重登刷新本地缓存（持久缓存可能残留 email 空的旧值）
    if (!await _reloginForFreshCache(tester, 'admin888s')) return;
    if (!await ensureStableSession(tester)) return;

    // 登录缓存此刻应含非空 email+mobile（回归：login_resp 补发 mobile）
    expect(
      UserRepoLocal.to.current.email.isNotEmpty,
      isTrue,
      reason: '登录缓存 email 应非空',
    );
    expect(
      UserRepoLocal.to.current.mobile.isNotEmpty,
      isTrue,
      reason: '登录缓存 mobile 应非空（后端 login_resp 补发 mobile 修复）',
    );

    // 测试内清 password（PG 直连构造「未设密」态），随后 set_password 成功
    await TestPg.execute('UPDATE "user" SET password=@p WHERE id=@id', {
      'p': '',
      'id': int.parse(_smokeUid),
    });

    await _go(tester, '/set_password');
    await _fillSetPassword(tester, 'admin888x');

    final okToast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('密码修改成功')),
      seconds: 10,
    );
    expect(okToast, isTrue, reason: '设密成功应有成功 toast');

    // email+mobile 均非空 → needGuide=false → BottomNavigationPage
    final mainNav = await _waitFor(
      tester,
      () => tester.any(find.byType(BottomNavigationPage)),
      seconds: 10,
    );
    expect(mainNav, isTrue, reason: '已绑定用户设密后应直达主导航（此前 mobile 恒空致分支不可达）');
    await TestPg.close();
  });

  testWidgets('AT-AS4 改密失败兜底+改密成功', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrap(tester)) return;
    await _expectSmokeUid();

    final hash = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    if (hash == null || hash.toString().isEmpty) {
      fail('AT-AS4 前置不满足：password 应为 admin888x（场景3 设置）');
    }

    await _go(tester, '/change_password');

    // 失败路径：旧密码故意填错 → 后端 errorPassword →
    // 本地化映射修复后用户应看到「密码错误」而非英文码
    await _fillChangePassword(tester, 'admin888', 'admin888c');
    final errToast = await _waitFor(
      tester,
      () => tester.any(find.text('密码错误')),
      seconds: 10,
    );
    expect(errToast, isTrue, reason: '旧密码错误应显示「密码错误」（修复前裸显 errorPassword）');
    final hashMid = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    expect(hashMid.toString(), hash.toString(), reason: '改密失败密码不得变化');

    // 成功路径：正确旧密码 → 提交 →「修改成功」
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Navigator).first),
      listen: false,
    );
    final st = container.read(changeLoginPasswordProvider);
    // ignore: avoid_print
    print(
      'DIAG AS4 二次提交前: existingLen=${st.existingPassword.length} '
      'newLen=${st.newPassword.length} confirmLen=${st.confirmLength} '
      'canSubmit=${st.canSubmit}',
    );
    await _fillChangePassword(tester, 'admin888x', 'admin888c');
    final st2 = container.read(changeLoginPasswordProvider);
    // ignore: avoid_print
    print(
      'DIAG AS4 二次提交后: isLoading=${st2.isLoading} '
      'canSubmit=${st2.canSubmit}',
    );
    final okToast = await _waitFor(
      tester,
      () => tester.any(find.textContaining('修改成功')),
      seconds: 10,
    );
    expect(okToast, isTrue, reason: '改密成功应有成功 toast');

    final hashAfter = await TestPg.scalar(
      'SELECT password FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    expect(
      hashAfter.toString() != hash.toString(),
      isTrue,
      reason: '改密成功后服务端 hash 应变化',
    );
    await TestPg.close();
  });

  testWidgets('AT-AS5 注销：二次确认→服务端落库→清理本地回欢迎页', (tester) async {
    if (!_allow) {
      markTestSkipped('需显式 TEST_ALLOW_GROUP_MEMBER_ACCEPTANCE=true');
      return;
    }
    if (!await _bootstrap(tester)) return;
    await _expectSmokeUid();

    // 前置自检：该账号此前无注销申请
    final pre = await TestPg.scalar(
      "SELECT status FROM \"user\" WHERE id=@id",
      {'id': int.parse(_smokeUid)},
    );
    if (pre.toString() == '2') {
      fail('AT-AS5 前置不满足：账号已在注销申请中（重复执行请先编排清场）');
    }

    await _go(tester, '/logout_account');

    // 勾选「已阅读并同意」条款（未勾选时注销按钮禁用）；
    // CupertinoCheckbox 点击区小，用中心坐标点
    final checkbox = find.byType(CupertinoCheckbox);
    if (!tester.any(checkbox)) {
      fail('注销页条款 Checkbox 不存在');
    }
    final cbCenter = tester.getCenter(checkbox.first);
    await tester.tapAt(cbCenter);
    await _pump(tester, seconds: 1);
    final checked = await _waitFor(
      tester,
      () => tester
          .widgetList<CupertinoCheckbox>(checkbox)
          .any((w) => w.value == true),
      seconds: 3,
    );
    expect(checked, isTrue, reason: '条款 Checkbox 应可勾选');

    // 注销按钮（红色破坏色）→ 二次确认弹窗
    await _tapText(tester, '注销账号');
    final dialogShown = await _waitFor(
      tester,
      () => tester.any(find.textContaining('确定要注销账号吗')),
      seconds: 6,
    );
    expect(dialogShown, isTrue, reason: '应弹不可逆二次确认弹窗');

    // 弹窗内「注销账号」（isDestructiveAction）确认
    final destructive = find.text('注销账号');
    await tester.tap(destructive.last, warnIfMissed: false);
    await _pump(tester, seconds: 3);

    // 服务端执行 apply_logout + 客户端 quitLogin + go('/welcome')
    final onWelcome = await _waitFor(
      tester,
      () => tester.any(find.byType(WelcomePage)),
      seconds: 15,
    );
    expect(onWelcome, isTrue, reason: '注销成功应清理本地并跳欢迎页');

    // 服务端断言：用户置注销申请态（status=2）+ 申请窄记录 requested
    final status = await TestPg.scalar(
      'SELECT status FROM "user" WHERE id=@id',
      {'id': int.parse(_smokeUid)},
    );
    expect(status.toString(), '2', reason: '用户应进入注销申请态（宽限期）');

    final reqStatus = await TestPg.scalar(
      'SELECT status FROM user_deletion_request WHERE user_id=@id '
      'ORDER BY requested_at DESC LIMIT 1',
      {'id': int.parse(_smokeUid)},
    );
    expect(reqStatus.toString(), 'requested', reason: '应有 requested 注销申请记录');
    await TestPg.close();
  });
}
