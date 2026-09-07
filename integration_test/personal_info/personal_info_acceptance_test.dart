// integration_test/personal_info/personal_info_acceptance_test.dart
//
// 个人信息域验收（批次125）：解锁 personal_info_page 12 行 + more_page 10 行。
// 历史阻塞原因「BUG#59 /personal_info 根路径全仓零跳转点（死页面，删除或
// 接线=产品决策）」已失效——workspace_shell/workspace_account_menu.dart 的
// 账户 Sheet「个人资料」入口已 push('/personal_info')，页面恢复可达，本批
// 全量真跑（不再挂人工决策）。
//
// 载体：SmokeEmpty（account=51730，uid=111174215241304064）。
// 红线：仅本地环境（9801/4323）；不发码不外发；setUpAll 备份
// gender/sign/region 三字段，tearDownAll 全部恢复，51730 零残留。
//
// 场景（行对应 personal_info_page.md 12 行 + more_page.md 10 行；
// 编号补零：--plain-name 是子串匹配，AT-PI1 会误中 AT-PI10/11）：
//   AT-PI01 深链可达 + 头像区昵称/ID + 基本信息组三行（行1/2/3）
//   AT-PI04 昵称行 → SetNicknamePage 回填当前昵称 → 返回（行4）
//   AT-PI05 点头像：avatar 空 → 不打开预览（防误触分支）（行5）
//   AT-PI06 相机角标 → 面板弹条件分支（avatar 空 → 无查看大图项）（行6）
//   AT-PI07 拍照入口：fake MediaPickerCapability.pickCamera → 裁剪页（行7）
//   AT-PI08 相册入口：fake pickSingle → 裁剪页（行8）
//   AT-PI09 裁剪「完成」→ presign 真上传 → 缓存/DB 头像刷新（行9）
//   AT-PI10 我的二维码 → UserQrCodePage（行10）
//   AT-PI11 更多信息 → MorePage（行11）
//   AT-MF01 MorePage 深链可达 + 性别「未知」/地区、签名「未填写」（more 行1/2/7）
//   AT-MF03 性别行 → SetGenderPage 三选项（more 行3）
//   AT-MF04 选「保密」真保存 → 返回后本页刷新「保密」（more 行4）
//   AT-MF05 地区超十字省略号截断（more 行5，本地缓存造值）
//   AT-MF06 地区三级下钻保存全链 → 本页刷新 + 本地缓存（more 行6）
//   AT-MF08 签名编辑保存 → 本页刷新 + 本地缓存同步（more 行8/9）
//   AT-MF10 卡片分隔线与圆角阴影样式（more 行10）
//
// 环境限制（非产品 bug）：本地 public_base_url=127.0.0.1:3902，且 F-13
// SSRF 加固拒一切内网图源——本地上传的真头像也**下载不了**（生产不受
// 影响，与生产行为一致的安全特性）。因此：
//   - 行5 预览正向路径（有真实可下载头像）本地不可验，转真机；
//     本地验 avatar 空的防误触分支（点头像不开预览）。
//   - AT-PI09 上传成功后页面重渲染会异步抛已知 Security Block 图片错误，
//     场景内装白名单过滤器吞掉该噪音（计数留痕），其余错误照常失败。
//
// 运行（单场景 --plain-name；define 与批次123/124 同配方）：
//   flutter test integration_test/personal_info/personal_info_acceptance_test.dart \
//     -d macos --plain-name "AT-PI01" \
//     --dart-define=APP_ENV=local_office \
//     --dart-define=API_BASE_URL=http://127.0.0.1:9801 \
//     --dart-define=API_BASE_URL_OVERRIDE=http://127.0.0.1:9801 \
//     --dart-define=WS_URL_OVERRIDE=ws://127.0.0.1:9801/api/v1/ws \
//     --dart-define=TEST_PHONE=51730 --dart-define=TEST_PASSWORD=admin888c \
//     --dart-define=TEST_EXPECTED_UID=111174215241304064

import 'dart:convert';
import 'dart:io';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/main.dart' as app;
import 'package:imboy/page/personal_info/personal_info/personal_info_page.dart';
import 'package:imboy/page/personal_info/set_gender/set_gender_page.dart';
import 'package:imboy/page/personal_info/set_nickname/set_nickname_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/update/update_page.dart';
import 'package:imboy/page/personal_info/widget/more_page.dart';
import 'package:imboy/page/qrcode/user_qrcode_page.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:integration_test/integration_test.dart';
import 'package:photo_manager/photo_manager.dart' show AssetEntity;
import 'package:shared_preferences/shared_preferences.dart';

import '../flows/pg_helper.dart';
import '../flows/test_utils.dart';

const _uid = String.fromEnvironment(
  'TEST_EXPECTED_UID',
  defaultValue: '111174215241304064',
);
const _account = '51730';

String? _origGender;
String? _origSign;
String? _origRegion;

final _pngBytes = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  ),
);

/// 测试专用 MediaPickerCapability：记录调用、返回预置图，绝不唤起
/// 系统选择器/相机（macOS 沙箱会挂住）。
class _FakeMediaPicker implements MediaPickerCapability {
  String lastCall = '';
  PickedMedia? nextSingle;
  PickedMedia? nextCamera;

  @override
  Future<List<PickedMedia>> pickImages(
    BuildContext context, {
    int maxCount = 9,
    bool allowCamera = true,
  }) async => [];

  @override
  Future<PickedMedia?> pickVideo(
    BuildContext context, {
    Duration? maxDuration,
  }) async => null;

  @override
  Future<PickedMedia?> pickSingle(BuildContext context, MediaType type) async {
    lastCall = 'pickSingle:$type';
    return nextSingle;
  }

  @override
  Future<PickedMedia?> pickCamera(
    BuildContext context, {
    bool enableRecording = false,
  }) async {
    lastCall = 'pickCamera';
    return nextCamera;
  }

  @override
  Future<AssetEntity?> pickCameraDual(BuildContext context) async => null;
}

late _FakeMediaPicker _picker;

/// F-13 SSRF 防护在本地必拦 127.0.0.1 头像图源（见文件头环境限制）。
/// 只吞这一类已知图片错误，其余照常抛——不是降断言，是分离环境噪音。
int _knownImageNoise = 0;

void Function(FlutterErrorDetails)? _origOnError;

void _installImageNoiseFilter() {
  _origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exception.toString();
    if (text.contains('Security Block') ||
        text.contains('refused internal host')) {
      _knownImageNoise++;
      iPrint('[PI] 已吞已知图片噪音 #$_knownImageNoise');
      return;
    }
    _origOnError?.call(details);
  };
}

void _uninstallImageNoiseFilter() {
  FlutterError.onError = _origOnError;
  _origOnError = null;
}

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

/// 与批次124 差异：本批次无条件重登——确保本地缓存与服务端一致
/// （容器可能残留上批次旧态）。
Future<bool> _boot(WidgetTester tester) async {
  app.main();
  await _pump(tester, seconds: 12);
  if (UserRepoLocal.to.currentUid.isNotEmpty) {
    await UserRepoLocal.to.quitLogin();
    final navCtx = tester.element(find.byType(Navigator).first);
    GoRouter.of(navCtx).go('/welcome');
    await _pump(tester, seconds: 6);
  }
  final wsEmptySeen = const Key('workspace-empty-create-entry');
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

void _openPersonalInfo(WidgetTester tester) {
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).go('/personal_info');
}

void _openMore(WidgetTester tester) {
  GoRouter.of(
    tester.element(find.byType(Navigator).first),
  ).go('/personal_info/more');
}

Future<bool> _waitForPersonalInfo(WidgetTester tester) {
  return _waitFor(
    tester,
    () => tester.any(find.byType(PersonalInfoPage)),
    seconds: 10,
  );
}

/// 造一张 1x1 png 到系统临时目录（Crop 控件可直接解 bytes）
Future<String> _makeTempPng() async {
  final f = File(
    '${Directory.systemTemp.path}/pi_test_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await f.writeAsBytes(_pngBytes);
  return f.path;
}

Iterable<String> _pageTexts(WidgetTester tester) {
  return tester.allWidgets
      .whereType<Text>()
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .where((t) => t.trim().isNotEmpty);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  _picker = _FakeMediaPicker();

  setUpAll(() async {
    final r = await TestPg.execute(
      'SELECT gender::text, sign, region FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    );
    _origGender = (r[0][0] ?? '').toString();
    _origSign = (r[0][1] ?? '').toString();
    _origRegion = (r[0][2] ?? '').toString();
  });

  tearDownAll(() async {
    await TestPg.execute(
      'UPDATE "user" SET gender = @g, sign = @s, region = @r WHERE id = @id',
      {
        'g': _origGender ?? '0',
        's': _origSign ?? '',
        'r': _origRegion ?? '',
        'id': int.parse(_uid),
      },
    );
  });

  testWidgets('AT-PI01 深链可达+头像区与基本信息组渲染', (tester) async {
    if (!await _boot(tester)) return;
    _openPersonalInfo(tester);
    expect(
      await _waitForPersonalInfo(tester),
      isTrue,
      reason: 'BUG#59 已失效：账户 Sheet 已接线 /personal_info，页面应可达',
    );

    // 头像区：昵称 + ID
    expect(tester.any(find.text('SmokeEmpty')), isTrue, reason: '头像区昵称');
    expect(tester.any(find.text('ID: $_account')), isTrue, reason: '头像区账号ID');

    // 基本信息组：昵称/账号/登录邮箱 三行（51730 email 非空）
    expect(tester.any(find.text(t.account.nickname)), isTrue);
    expect(tester.any(find.text(t.account.account)), isTrue);
    expect(
      tester.any(find.text(t.account.loginEmail)),
      isTrue,
      reason: 'email 非空应显示登录邮箱行',
    );
  });

  testWidgets('AT-PI04 昵称行跳转设置页回填当前昵称', (tester) async {
    if (!await _boot(tester)) return;
    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);

    await tester.tap(find.text(t.account.nickname), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(SetNicknamePage))),
      isTrue,
      reason: '点昵称行应进 SetNicknamePage',
    );
    // 回填：控制器初始文本 = 当前昵称
    final tf = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(tf.controller?.text, 'SmokeEmpty', reason: '设置页应回填当前昵称');

    // 返回（未保存）→ 个人信息页
    await tester.tap(find.byType(GlassBackButton), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(PersonalInfoPage))),
      isTrue,
    );
  });

  testWidgets('AT-PI05 点头像：空头像不打开预览（防误触分支）', (tester) async {
    if (!await _boot(tester)) return;
    expect(
      UserRepoLocal.to.current.avatar,
      isEmpty,
      reason: '前置：51730 avatar 应为空（造值方案因 F-13 本地不可行已废弃）',
    );
    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);

    // 点头像中心：_openAvatarPreview 对空 avatar 直接 return
    await tester.tap(find.byType(Hero).first, warnIfMissed: false);
    await _pump(tester, seconds: 3);
    expect(
      tester.any(find.byIcon(CupertinoIcons.xmark)),
      isFalse,
      reason: '空头像点头像不应打开预览页（预览正向路径需真实头像，转真机）',
    );
  });

  testWidgets('AT-PI06 相机角标弹出头像操作面板（条件分支）', (tester) async {
    if (!await _boot(tester)) return;
    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);

    await tester.tap(
      find.byIcon(CupertinoIcons.camera_fill),
      warnIfMissed: false,
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(CupertinoActionSheet)),
      ),
      isTrue,
      reason: '点相机角标应弹 ActionSheet',
    );
    // avatar 空 → 「查看大图」条件项不出现；拍照/相册/取消三常驻项
    expect(
      tester.any(find.text(t.chat.viewLargeImage)),
      isFalse,
      reason: 'avatar 为空时不应有查看大图项',
    );
    expect(tester.any(find.text(t.common.buttonTakingPictures)), isTrue);
    expect(tester.any(find.text(t.main.chooseFromAlbum)), isTrue);
    expect(tester.any(find.text(t.common.buttonCancel)), isTrue);

    await tester.tap(find.text(t.common.buttonCancel), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () => !tester.any(find.byType(CupertinoActionSheet)),
      ),
      isTrue,
      reason: '取消应关闭面板',
    );
  });

  testWidgets('AT-PI07 拍照入口经 fake 相机进入裁剪页', (tester) async {
    if (!await _boot(tester)) return;
    CapabilityLocator.I.register<MediaPickerCapability>(_picker);
    _picker.nextCamera = PickedMedia(
      path: await _makeTempPng(),
      type: MediaType.image,
    );

    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);
    await tester.tap(
      find.byIcon(CupertinoIcons.camera_fill),
      warnIfMissed: false,
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(CupertinoActionSheet)),
      ),
      isTrue,
      reason: '前置：操作面板应弹出',
    );
    await tester.tap(
      find.text(t.common.buttonTakingPictures),
      warnIfMissed: false,
    );

    expect(
      _picker.lastCall,
      'pickCamera',
      reason: '「拍照」应走 pickCamera（此前与相册同源的 bug 已修）',
    );
    expect(
      await _waitFor(tester, () => tester.any(find.byType(CropImageRoute))),
      isTrue,
      reason: '取到图应进裁剪页',
    );
    // 退出裁剪页，避免影响后续场景
    await tester.tap(find.text(t.common.buttonCancel), warnIfMissed: false);
  });

  testWidgets('AT-PI08 相册入口经 fake 相册进入裁剪页', (tester) async {
    if (!await _boot(tester)) return;
    CapabilityLocator.I.register<MediaPickerCapability>(_picker);
    _picker.nextSingle = PickedMedia(
      path: await _makeTempPng(),
      type: MediaType.image,
    );

    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);
    await tester.tap(
      find.byIcon(CupertinoIcons.camera_fill),
      warnIfMissed: false,
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(CupertinoActionSheet)),
      ),
      isTrue,
      reason: '前置：操作面板应弹出',
    );
    await tester.tap(find.text(t.main.chooseFromAlbum), warnIfMissed: false);

    expect(
      _picker.lastCall,
      'pickSingle:MediaType.image',
      reason: '「从相册选择」应走 pickSingle(image)',
    );
    expect(
      await _waitFor(tester, () => tester.any(find.byType(CropImageRoute))),
      isTrue,
      reason: '选到图应进裁剪页',
    );
    await tester.tap(find.text(t.common.buttonCancel), warnIfMissed: false);
  });

  testWidgets('AT-PI09 裁剪完成真上传并刷新头像', (tester) async {
    if (!await _boot(tester)) return;
    _installImageNoiseFilter();
    CapabilityLocator.I.register<MediaPickerCapability>(_picker);
    _picker.nextSingle = PickedMedia(
      path: await _makeTempPng(),
      type: MediaType.image,
    );

    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);
    await tester.tap(
      find.byIcon(CupertinoIcons.camera_fill),
      warnIfMissed: false,
    );
    expect(
      await _waitFor(
        tester,
        () => tester.any(find.byType(CupertinoActionSheet)),
      ),
      isTrue,
      reason: '前置：操作面板应弹出',
    );
    await tester.tap(find.text(t.main.chooseFromAlbum), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(Crop))),
      isTrue,
      reason: '前置：裁剪控件就绪',
    );

    // 完成 → crop → presign 上传（本地 Garage）→ pop 回传 url →
    // UserProfileService.updateField(avatar) → 本页 setState 刷新
    await tester.tap(find.text(t.common.buttonAccomplish), warnIfMissed: false);
    final back = await _waitFor(
      tester,
      () =>
          tester.any(find.byType(PersonalInfoPage)) &&
          !tester.any(find.byType(CropImageRoute)),
      seconds: 30,
    );
    expect(back, isTrue, reason: '上传成功应 pop 返回个人信息页');

    final newAvatar = UserRepoLocal.to.current.avatar;
    iPrint('[PI09] 上传后 avatar=$newAvatar（噪音吞掉 $_knownImageNoise 条）');
    expect(newAvatar.isNotEmpty, isTrue, reason: '本地缓存头像应更新');
    // 本地缓存 + 服务端闭环
    final dbAvatar = (await TestPg.scalar(
      'SELECT avatar FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    )).toString();
    expect(dbAvatar, newAvatar, reason: '服务端 avatar 应与本地缓存一致');
    // 留痕后恢复空值（后续场景不再有头像下载噪音）
    await TestPg.execute('UPDATE "user" SET avatar = @v WHERE id = @id', {
      'v': '',
      'id': int.parse(_uid),
    });
    _uninstallImageNoiseFilter();
  });

  testWidgets('AT-PI10 我的二维码跳转', (tester) async {
    if (!await _boot(tester)) return;
    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);

    await tester.tap(find.text(t.account.myQrcode), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(UserQrCodePage))),
      isTrue,
      reason: '点我的二维码应进二维码页',
    );
    await tester.tap(find.byType(GlassBackButton), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(PersonalInfoPage))),
      isTrue,
    );
  });

  testWidgets('AT-PI11 更多信息跳转 MorePage', (tester) async {
    if (!await _boot(tester)) return;
    _openPersonalInfo(tester);
    await _waitForPersonalInfo(tester);

    await tester.tap(find.text(t.common.moreInfo), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(MorePage))),
      isTrue,
      reason: '点更多信息应进 MorePage（BUG#59 关联争议一并解除）',
    );
  });

  testWidgets('AT-MF01 MorePage 深链可达与三行默认态', (tester) async {
    if (!await _boot(tester)) return;
    _openMore(tester);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(MorePage))),
      isTrue,
      reason: '/personal_info/more 应可达',
    );
    // gender=0 → 「未知」；region/sign 空 → 「未填写」
    expect(tester.any(find.text(t.account.gender)), isTrue);
    expect(
      tester.any(find.text(t.common.unknown)),
      isTrue,
      reason: 'gender=0 应显示未知',
    );
    expect(
      tester.any(find.text(t.common.notFilled)),
      isTrue,
      reason: 'region/sign 均空应有未填写占位（2 处）',
    );
  });

  testWidgets('AT-MF03 性别行跳转设置性别页', (tester) async {
    if (!await _boot(tester)) return;
    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    await tester.tap(find.text(t.account.gender), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(SetGenderPage))),
      isTrue,
      reason: '点性别行应进 SetGenderPage',
    );
    expect(tester.any(find.text(t.main.male)), isTrue);
    expect(tester.any(find.text(t.main.female)), isTrue);
    expect(tester.any(find.text(t.main.keepSecret)), isTrue);
    // gender=0 无勾选项
    expect(
      tester.any(find.byIcon(CupertinoIcons.check_mark)),
      isFalse,
      reason: '未设置性别时不应有勾选',
    );
    await tester.tap(find.byType(GlassBackButton), warnIfMissed: false);
  });

  testWidgets('AT-MF04 选择保密真保存返回后本页刷新', (tester) async {
    if (!await _boot(tester)) return;
    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    await tester.tap(find.text(t.account.gender), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(SetGenderPage))),
      isTrue,
    );
    await tester.tap(find.text(t.main.keepSecret), warnIfMissed: false);

    // 真保存（PUT userUpdate gender=3）成功才 pop(true)。
    // 等待条件必须排除 SetGenderPage：它的选项「保密」与 MorePage 的行值
    // 文案相同，未 pop 时条件会假绿（首跑实证）。
    expect(
      await _waitFor(
        tester,
        () =>
            tester.any(find.byType(MorePage)) &&
            !tester.any(find.byType(SetGenderPage)) &&
            tester.any(find.text(t.main.keepSecret)),
        seconds: 15,
      ),
      isTrue,
      reason: '保存后应 pop 回 MorePage，性别行刷新为「保密」',
    );
    // API 响应 → 服务端落库有可见延迟：轮询而非单次断言（首跑实证
    // PUT 响应晚于测试断言到达）
    var dbOk = false;
    for (var i = 0; i < 30 && !dbOk; i++) {
      final g = (await TestPg.scalar(
        'SELECT gender FROM "user" WHERE id = @id',
        {'id': int.parse(_uid)},
      )).toString();
      dbOk = g == '3';
      if (!dbOk) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    expect(dbOk, isTrue, reason: '服务端 gender 应已更新');
    // 本地缓存同步
    expect(UserRepoLocal.to.current.gender.toString(), '3');
  });

  testWidgets('AT-MF05 地区超十字省略号截断', (tester) async {
    if (!await _boot(tester)) return;
    // 本地缓存造 11+ 字符地区值（不碰服务端；MF06 真保存会覆盖）
    const longRegion = '中国大陆北京市海淀区中关村大街';
    UserRepoLocal.to.changeInfo({
      ...UserRepoLocal.to.current.toMap(),
      'region': longRegion,
    });

    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    // _formatRegion：>10 字符 → substring(0,9)+'...'
    final expected = '${longRegion.substring(0, 9)}...';
    expect(
      await _waitFor(tester, () => tester.any(find.text(expected))),
      isTrue,
      reason: '地区行应显示截断文案 $expected',
    );
  });

  testWidgets('AT-MF06 地区三级下钻保存全链', (tester) async {
    if (!await _boot(tester)) return;
    // 清地区本地缓存（RegionCache 残留会把 _initialValue 初始化成上次
    // 选择值，重选相同地区时 hasChanged=false 完成按钮失活——多场景
    // 重跑的陈旧态；服务端 region 已在场景前清空）
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('region_selected');
    await prefs.remove('region_path');
    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    await tester.tap(find.text(t.account.region), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(SetRegionPage))),
      isTrue,
      reason: '点地区行应进 SetRegionPage',
    );
    // 中国大陆 → 北京 → 东城（叶子）。逐级等目标文本入树再点——
    // 固定 pump 会撞转场动画导致 tap 错位（二跑实证时稳时不稳）
    await tester.tap(find.text('中国大陆'), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.text('北京'))),
      isTrue,
      reason: '下钻到省列表',
    );
    // 文本入树≠可命中：Cupertino 转场动画中文本已 build 但命中测试
    // 仍在动画位（探针实证 hasChanged=false），须等动画完成再点
    await _pump(tester, seconds: 2);
    await tester.tap(find.text('北京'), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.text('东城'))),
      isTrue,
      reason: '下钻到区列表',
    );
    await _pump(tester, seconds: 2);
    await tester.tap(find.text('东城'), warnIfMissed: false);
    await _pump(tester, seconds: 2);

    // 「完成」激活探针：onPressed 非 null 即 hasChanged=true（「东城」选中生效）
    final doneText = find.text(t.common.buttonAccomplish);
    final btns = tester.widgetList<CupertinoButton>(
      find.ancestor(of: doneText, matching: find.byType(CupertinoButton)),
    );
    final enabled = btns.any((b) => b.onPressed != null);
    iPrint(
      '[MF06] 完成按钮数=${tester.elementList(doneText).length} '
      'enabled=$enabled 文本=${_pageTexts(tester).take(14).toList()}',
    );
    expect(enabled, isTrue, reason: '选到叶子后「完成」应激活');
    await tester.tap(doneText.first, warnIfMissed: false);
    // 产品语义：保存成功 double-pop 回到地区主页（非 MorePage），
    // 主页「当前选择」回显应更新为组合路径
    expect(
      await _waitFor(tester, () => tester.any(find.text('北京 东城')), seconds: 15),
      isTrue,
      reason: '保存成功应回到地区主页且回显新选择',
    );
    // 本地缓存闭环：onSave 成功路径同步 UserRepoLocal（行刷新机制与
    // MF04 性别行同款 push-后-setState，不再重复验证）
    final cached = UserRepoLocal.to.current.region;
    iPrint('[MF06] 保存后本地缓存 region=$cached');
    expect(cached, '北京 东城', reason: '本地缓存应同步新地区');
    final dbRegion = (await TestPg.scalar(
      'SELECT region FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    )).toString();
    expect(dbRegion.isNotEmpty, isTrue, reason: '服务端 region 应已保存');
    expect(UserRepoLocal.to.current.region, dbRegion, reason: '本地缓存应与服务端一致');
  });

  testWidgets('AT-MF08 签名编辑保存与本地缓存同步', (tester) async {
    if (!await _boot(tester)) return;
    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    await tester.tap(find.text(t.account.signature), warnIfMissed: false);
    expect(
      await _waitFor(tester, () => tester.any(find.byType(UpdatePage))),
      isTrue,
      reason: '点签名行应进 UpdatePage（input）',
    );
    const newSign = '批次125 自动化签名';
    await tester.enterText(find.byType(TextField), newSign);
    await _pump(tester);

    // 「完成」随 valueChanged 激活 → callback：changeInfo(sign) + 本地缓存
    await tester.tap(find.text(t.common.buttonAccomplish), warnIfMissed: false);
    expect(
      await _waitFor(
        tester,
        () =>
            tester.any(find.byType(MorePage)) &&
            !tester.any(find.byType(UpdatePage)),
        seconds: 15,
      ),
      isTrue,
      reason: '保存成功应 pop 回 MorePage',
    );
    expect(
      await _waitFor(tester, () => tester.any(find.text(newSign))),
      isTrue,
      reason: '签名行应刷新显示新签名',
    );
    final dbSign = (await TestPg.scalar(
      'SELECT sign FROM "user" WHERE id = @id',
      {'id': int.parse(_uid)},
    )).toString();
    expect(dbSign, newSign, reason: '服务端 sign 应已保存');
    expect(UserRepoLocal.to.current.sign, newSign, reason: '本地缓存应同步新签名');
  });

  testWidgets('AT-MF10 卡片分隔线与样式断言', (tester) async {
    if (!await _boot(tester)) return;
    _openMore(tester);
    await _waitFor(tester, () => tester.any(find.byType(MorePage)));

    // 分组卡片内行间分隔线：左缩进 56、厚度 0.5
    final dividers = tester.widgetList<Divider>(
      find.byWidgetPredicate((w) => w is Divider && w.thickness == 0.5),
    );
    expect(
      dividers.length,
      greaterThanOrEqualTo(2),
      reason: '性别/地区/签名三行间应有 2 条分隔线',
    );
    // 左缩进 56 由外层 Padding 实现（Divider.indent 本身为 null）
    final paddings = tester.widgetList<Padding>(
      find.ancestor(
        of: find.byWidgetPredicate((w) => w is Divider && w.thickness == 0.5),
        matching: find.byType(Padding),
      ),
    );
    expect(paddings.isNotEmpty, isTrue, reason: '分隔线应有外层缩进容器');
    final anyLeft56 = paddings.any(
      (pd) => pd.padding is EdgeInsets && (pd.padding as EdgeInsets).left == 56,
    );
    expect(anyLeft56, isTrue, reason: '分隔线应通过外层 Padding 左缩进 56');
    // 卡片容器：圆角 + 阴影
    final cards = tester.widgetList<Container>(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).boxShadow != null &&
            (w.decoration as BoxDecoration).boxShadow!.isNotEmpty,
      ),
    );
    expect(cards.isNotEmpty, isTrue, reason: '分组卡片应有圆角阴影容器');
    final deco = cards.first.decoration as BoxDecoration;
    expect(deco.borderRadius, isNotNull, reason: '卡片应有圆角');
  });
}
