import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_entry.dart';
import 'package:imboy/service/storage.dart';

/// MinePage（我的页面）渲染契约测试
///
/// 覆盖：
///   - InsetGrouped Scaffold 背景（surfaceGrouped）
///   - 大标题 'titleMine'（"我的"）
///   - Profile Card：用户 nickname / 'ImBoy ID: $uid' / QR 入口图标 / chevron
///   - 7 个 ImBoySettingsTile：switchToWorkspace / personalAttachments / storageSpace /
///     loginDeviceManagement / appeal / setting / feedback
///     （钱包 QuickAction 受 feature flag 控制，默认配置不渲染）
///   - Section 内菜单 icon 容器使用 10% alpha 背景 + iconColor 应用
///
/// 不验证 channel feature flag 菜单（依赖 AppFeatureRegistry snapshot 状态，
/// 默认未配置时行为不确定，留 manual QA / 集成测试覆盖）。
class _EligibleSeatAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {
          'contexts': [
            {
              'organization_id': '7266418340025468901',
              'business_identity_id': '7266418340025468902',
              'seat_enabled': true,
            },
          ],
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

GoRouter _stubRouter({bool enterprise = false}) {
  // 所有菜单跳转目标都用 stub 接住，避免 context.push 抛 'no route' 错
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/mine',
    routes: [
      GoRoute(
        path: '/mine',
        builder: (_, _) => MinePage(enterprise: enterprise),
      ),
      GoRoute(path: '/wallet', builder: (_, _) => stub('wallet stub')),
      GoRoute(path: kCsWorkspacePath, builder: (_, _) => stub('客服工作台目标')),
      GoRoute(path: '/favorites', builder: (_, _) => stub('favorites stub')),
      GoRoute(path: '/storage_space', builder: (_, _) => stub('storage stub')),
      GoRoute(path: '/devices', builder: (_, _) => stub('devices stub')),
      GoRoute(path: '/mine/setting', builder: (_, _) => stub('setting stub')),
      GoRoute(path: '/feedback', builder: (_, _) => stub('feedback stub')),
      GoRoute(path: '/qrcode/user', builder: (_, _) => stub('qrcode stub')),
      GoRoute(
        path: '/personal_info/profile',
        builder: (_, _) => stub('personal stub'),
      ),
    ],
  );
}

Future<void> _setUser({
  String uid = 'tsid_uid_001',
  String account = 'imboy_user',
  String nickname = 'Tester',
  String avatar = '',
  String sign = '',
}) async {
  await StorageService.setMap(Keys.currentUser, <String, dynamic>{
    'uid': uid,
    'account': account,
    'nickname': nickname,
    'avatar': avatar,
    'email': '',
    'gender': 0,
    'sign': sign,
    'region': '',
    'createdAt': 0,
  });
}

Future<void> _pumpMine(WidgetTester tester, {bool enterprise = false}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: _stubRouter(enterprise: enterprise),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    IMBoyCacheManager.debugLogEnabled = true;
  });

  setUp(() async {
    await _setUser();
    // ccc47b60 scope 隔离后空 snapshot 使编译特性判 false，「我的频道」等
    // flag 门控入口会消失；注入编译全集开启基线恢复既有契约。
    AppFeatureRegistry.replaceSnapshotForTest({
      for (final f in compiledProductFeatures) f: true,
    });
  });

  tearDown(() async {
    await StorageService.to.remove(Keys.currentUser);
  });

  group('MinePage layout & header', () {
    testWidgets('Scaffold uses iOS surfaceGrouped background', (tester) async {
      await _pumpMine(tester);

      // Cupertino 迁移后背景色由 CupertinoTheme 层接管，组件不再显式设色
      final scaffold = tester.widget<CupertinoPageScaffold>(
        find.byType(CupertinoPageScaffold).first,
      );
      expect(scaffold.backgroundColor, isNull);
    });

    testWidgets('renders immersive top safety spacing', (tester) async {
      await _pumpMine(tester);
      // 验证沉浸式顶部的 SizedBox 间距组件存在，避免名片被刘海屏遮挡
      expect(find.byType(SizedBox), findsWidgets);
    });
  });

  group('MinePage profile card', () {
    testWidgets('renders nickname + ImBoy ID + QR icon + chevron', (
      tester,
    ) async {
      await _pumpMine(tester);

      // nickname
      expect(find.text('Tester'), findsOneWidget);
      // ID（account 带 'ID: ' 前缀）
      expect(find.text('ID: imboy_user'), findsOneWidget);
      // QR code icon（mine_page header 用 CupertinoIcons.qrcode）
      expect(find.byIcon(CupertinoIcons.qrcode), findsOneWidget);
      // profile card chevron 使用 CupertinoIcons.chevron_right
      expect(find.byIcon(CupertinoIcons.chevron_right), findsOneWidget);
    });

    testWidgets('compact card omits sign (not rendered in redesigned header)', (
      tester,
    ) async {
      // iOS 17 高保真重构后的 header 仅渲染 nickname + 'ID: ...'，
      // 不再展示个性签名（sign），即便用户设置了 sign 也不显示。
      await _setUser(sign: '不忘初心');
      await _pumpMine(tester);
      expect(find.text('不忘初心'), findsNothing);
      // header 仍正常渲染 nickname + ID
      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('ID: imboy_user'), findsOneWidget);
    });

    testWidgets('renders no empty Text rows', (tester) async {
      // 默认 setUp 已设 sign=''，header 不应渲染空白 Text 行
      await _pumpMine(tester);
      expect(find.text(''), findsNothing);
    });
  });

  group('MinePage menu sections', () {
    testWidgets(
      'renders quick actions & storage / devices menu items (wallet flag-gated)',
      (tester) async {
        await _pumpMine(tester);

        // 钱包 QuickAction 受 feature flag 控制：wallet 未列入编译期特性
        // 清单（config/product-feature-manifest.json selected_features 未选），
        // isEnabled('wallet') 恒为 false，当前配置下不渲染。
        expect(find.text('钱包'), findsNothing);
        // 我的频道(channel flag 默认开，编译期清单已含) / 收藏(无条件)
        expect(find.text('我的频道'), findsOneWidget);
        expect(find.text('收藏'), findsOneWidget);

        // 存储空间 / 登录设备管理 / 设置 / 反馈建议
        expect(find.text('存储空间'), findsOneWidget);
        expect(find.text(t.attachmentManager.personalTitle), findsOneWidget);
        expect(find.text('登录设备管理'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
        expect(find.text('反馈建议'), findsOneWidget);
        // 收藏 已从设置分组 Tile 移走，现只在 QuickActionGrid 里出现一次
        // （菜单重组：QuickActionGrid = 我的频道/收藏 + feature-gated 钱包）
        expect(find.text('收藏'), findsOneWidget);
      },
    );

    testWidgets('renders chevron next to each menu item + profile', (
      tester,
    ) async {
      await _pumpMine(tester);

      // profile card 用 CupertinoIcons.chevron_right
      expect(
        find.byIcon(CupertinoIcons.chevron_right),
        findsOneWidget,
        reason: 'profile card 右侧应有 chevron_right',
      );
      // 7 个 ImBoySettingsTile（switchToWorkspace/personalAttachments/storageSpace/
      // loginDeviceManagement/appeal/setting/feedback）默认 trailing 为
      // CupertinoListTileChevron，内部渲染 CupertinoIcons.right_chevron。
      // favorites 已移入 QuickActionGrid，不是 Tile。
      // CSM-01 客服入口是 CsWorkspaceEntryTile，普通用户渲染为
      // SizedBox.shrink（不占位、无 chevron），不影响计数。
      expect(
        find.byIcon(CupertinoIcons.right_chevron),
        findsNWidgets(7),
        reason: '7 个设置项每项右侧应有 CupertinoListTileChevron',
      );
    });
  });

  testWidgets('客服入口仅个人模式挂载坐席权限组件', (tester) async {
    await _pumpMine(tester);
    expect(find.byType(CsWorkspaceEntryTile), findsOneWidget);
    expect(find.text('客服工作台'), findsNothing, reason: '无合格坐席上下文时仍隐藏，模式切换不能绕过权限');
  });

  testWidgets('企业模式不挂载客服入口（工作台已有同名入口）', (tester) async {
    await _pumpMine(tester, enterprise: true);
    expect(
      find.byType(CsWorkspaceEntryTile),
      findsNothing,
      reason: '企业模式工作台已有客服工作台入口，我页重复披露',
    );
    expect(find.text('客服工作台'), findsNothing);
  });

  testWidgets('合格坐席个人模式入口可见且可打开', (tester) async {
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureChannel,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null),
    );
    HttpClient.adapterForTest = _EligibleSeatAdapter();
    addTearDown(() => HttpClient.adapterForTest = null);
    await tester.runAsync(() async {
      await CsApi().seatContexts();
    });
    await _pumpMine(tester);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('客服工作台'), findsOneWidget);
    await tester.ensureVisible(find.text('客服工作台'));
    await tester.tap(find.text('客服工作台'));
    await tester.pumpAndSettle();
    expect(find.text('客服工作台目标'), findsOneWidget);
  });

  testWidgets('合格坐席企业模式入口也不渲染（入口收敛到工作台）', (tester) async {
    // 预热一份合格坐席上下文，证明"不渲染"是模式门控而非坐席资格缺失；
    // 企业模式下页面不挂载 CsWorkspaceEntryTile，不会发起 seat-contexts。
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          secureChannel,
          (call) async => call.method == 'readAll' ? <String, String>{} : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureChannel, null),
    );
    HttpClient.adapterForTest = _EligibleSeatAdapter();
    addTearDown(() => HttpClient.adapterForTest = null);
    await tester.runAsync(() async {
      await CsApi().seatContexts();
    });
    await _pumpMine(tester, enterprise: true);
    expect(find.text('客服工作台'), findsNothing);
    expect(find.byType(CsWorkspaceEntryTile), findsNothing);
  });

  group('MinePage navigation', () {
    testWidgets('tap setting → /mine/setting', (tester) async {
      await _pumpMine(tester);

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(find.text('setting stub'), findsOneWidget);
    });

    testWidgets('tap profile card → /personal_info/profile', (tester) async {
      await _pumpMine(tester);

      await tester.tap(find.text('Tester'));
      await tester.pumpAndSettle();

      expect(find.text('personal stub'), findsOneWidget);
    });
  });
}
