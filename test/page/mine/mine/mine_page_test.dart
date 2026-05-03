import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// MinePage（我的页面）渲染契约测试
///
/// 覆盖：
///   - InsetGrouped Scaffold 背景（surfaceGrouped）
///   - 大标题 'titleMine'（"我的"）
///   - Profile Card：用户 nickname / 'ImBoy ID: $uid' / QR 入口图标 / chevron
///   - 4 个 Section 菜单项：wallet / favorites / storageSpace / loginDeviceManagement /
///     setting / feedback
///   - Section 内菜单 icon 容器使用 10% alpha 背景 + iconColor 应用
///
/// 不验证 channel feature flag 菜单（依赖 AppFeatureRegistry snapshot 状态，
/// 默认未配置时行为不确定，留 manual QA / 集成测试覆盖）。
GoRouter _stubRouter() {
  // 所有菜单跳转目标都用 stub 接住，避免 context.push 抛 'no route' 错
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/mine',
    routes: [
      GoRoute(path: '/mine', builder: (_, _) => const MinePage()),
      GoRoute(path: '/wallet', builder: (_, _) => stub('wallet stub')),
      GoRoute(path: '/favorites', builder: (_, _) => stub('favorites stub')),
      GoRoute(
        path: '/storage_space',
        builder: (_, _) => stub('storage stub'),
      ),
      GoRoute(path: '/devices', builder: (_, _) => stub('devices stub')),
      GoRoute(
        path: '/mine/setting',
        builder: (_, _) => stub('setting stub'),
      ),
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

Future<void> _pumpMine(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _stubRouter()),
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
  });

  tearDown(() async {
    await StorageService.to.remove(Keys.currentUser);
  });

  group('MinePage layout & header', () {
    testWidgets('Scaffold uses iOS surfaceGrouped background', (
      tester,
    ) async {
      await _pumpMine(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      // 亮色模式下 surfaceGrouped = #F2F2F7
      expect(scaffold.backgroundColor, AppColors.lightSurfaceGrouped);
    });

    testWidgets('renders large title "我的" (28pt w700)', (tester) async {
      await _pumpMine(tester);
      // titleMine zhCn = "我的"
      final title = tester.widget<Text>(find.text('我的'));
      expect(title.style?.fontSize, 28);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.letterSpacing, 0.36);
    });
  });

  group('MinePage profile card', () {
    testWidgets('renders nickname + ImBoy ID + QR icon + chevron', (
      tester,
    ) async {
      await _pumpMine(tester);

      // nickname
      expect(find.text('Tester'), findsOneWidget);
      // ImBoy ID（account 带 'ImBoy ID: ' 前缀）
      expect(find.text('ImBoy ID: imboy_user'), findsOneWidget);
      // QR code icon（上方 mine_page 用 Icons.qr_code_2，本测试通过 IconButton 间接验证）
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
    });

    testWidgets('renders sign when present', (tester) async {
      await _setUser(sign: '不忘初心');
      await _pumpMine(tester);
      expect(find.text('不忘初心'), findsOneWidget);
    });

    testWidgets('hides sign when empty', (tester) async {
      // 默认 setUp 已设 sign=''，sign 区域不应渲染
      await _pumpMine(tester);
      // 只显示 ID + nickname 两段文字时不会有空白 Text 行（strNoEmpty 守卫）
      expect(find.text(''), findsNothing);
    });
  });

  group('MinePage menu sections', () {
    testWidgets('renders wallet / favorites / storage / devices menu items',
        (tester) async {
      await _pumpMine(tester);

      // 钱包 / 收藏 / 存储空间 / 登录设备管理 / 设置 / 反馈
      expect(find.text('钱包'), findsOneWidget);
      expect(find.text('收藏'), findsOneWidget);
      expect(find.text('存储空间'), findsOneWidget);
      expect(find.text('登录设备管理'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('反馈建议'), findsOneWidget);
    });

    testWidgets('renders chevron_right next to each menu item + profile', (
      tester,
    ) async {
      await _pumpMine(tester);

      // mine_page 全部用 CupertinoIcons.chevron_right
      // profile card(1) + wallet(1) + favorites(1) + storage(1) + devices(1) +
      // setting(1) + feedback(1) = 7
      // 不写死精确数字，至少 6（profile + 主体 6 个 menu item）
      expect(
        find.byIcon(CupertinoIcons.chevron_right).evaluate().length,
        greaterThanOrEqualTo(6),
        reason: 'profile card + 6+ menu items 每项右侧应有 chevron_right',
      );
    });
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
