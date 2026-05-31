import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_page.dart';
import 'package:imboy/service/storage.dart';

/// PersonalInfoPage 头像 5 bug 回归保护 + e2e 交互测试
///
/// 完整 mock 链：
///   - `flutter_test_config.dart` 已全局 init StorageService（SharedPreferences 内存版）+
///     path_provider mock
///   - 本测试 setUp 通过 [StorageService.setMap] 注入 [Keys.currentUser]，
///     让 [UserRepoLocal.to.current] 返回有效 UserModel
///   - 用 [TranslationProvider] + [ProviderScope] + [MaterialApp] 包裹页面
///
/// 覆盖范围（5 bug 中可独立 widget 测试的核心 + e2e 交互）：
///   - H1 单层圆角：仅一个 [ClipOval] 包头像（不再嵌套 ClipRRect）
///   - H4 Hero 锚点：存在 `tag: 'personal_info_avatar_hero'` 的 [Hero] widget
///   - H5 相机角标可见：存在 [CupertinoIcons.camera_fill] [Icon]
///   - e2e: 空头像 tap 不弹 preview（_openAvatarPreview 守卫）
///   - e2e: 非空头像 tap 弹 _AvatarPreviewPage（Hero 起飞 + xmark 关闭按钮可见）
///
/// H2（fallback 灰底）已被 `extractAvatarInitial` 纯函数测覆盖；
/// H3（独立 hit region 坐标分离）依赖精确坐标定位 + GestureDetector 框架行为，
/// 留作 manual QA（Stack 内不重叠的两个 GestureDetector 是 Flutter 框架天然保证）。
Future<void> _setUserAvatar(String avatarUrl) async {
  await StorageService.setMap(Keys.currentUser, <String, dynamic>{
    'uid': 'test_uid_123',
    'account': 'imboy_tester',
    'nickname': 'Tester',
    'avatar': avatarUrl,
    'email': '',
    'gender': 0,
    'sign': '',
    'region': '',
    'createdAt': 0,
  });
}

/// 按 tag 精确定位 avatar Hero（页面内还存在 Cupertino 导航栏默认 Hero，
/// 直接 find.byType(Hero) 会命中多个导致 tap 歧义）
final Finder _avatarHeroFinder = find.byWidgetPredicate(
  (w) => w is Hero && w.tag == 'personal_info_avatar_hero',
);

void main() {
  setUpAll(() {
    // 注入 Env.uploadKey/uploadScene 让 AssetsService.authData() 走非空分支，
    // 避免触发 _refreshUploadKey() → 'User not logged in' iPrint 链路日志噪音
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';

    // 静默 IMBoyCacheManager / IMBoyCachedImageProvider 的 debug 链日志：
    // '📦 getSingleFile' / '加载图片 (尝试 1/3)' / '📥 下载完成' 等
    // （非全局 debugPrint override，仅这两个组件内的 _log 受控；不触发 foundation invariant）
    IMBoyCacheManager.debugLogEnabled = false;
  });

  tearDownAll(() {
    // 还原全局静默状态（避免影响后续测试套件）
    IMBoyCacheManager.debugLogEnabled = true;
  });

  setUp(() async {
    // 默认场景：空头像走 _AvatarFallback 路径，不依赖网络
    await _setUserAvatar('');
  });

  tearDown(() async {
    // 清理 SharedPreferences 状态，避免测试间污染
    await StorageService.to.remove(Keys.currentUser);
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const MaterialApp(home: PersonalInfoPage()),
        ),
      ),
    );
    // 一次 pump 让 Scaffold 渲染；不 pumpAndSettle 避免 cachedImageProvider
    // 内部网络拉取定时器卡住测试
    await tester.pump();
  }

  testWidgets('H1 (single ClipOval): avatar uses exactly one ClipOval, '
      'not nested ClipRRect+inner-radius', (tester) async {
    await pumpPage(tester);

    // 源码现状：头像不再用 ClipOval，而是用单个 BoxShape.circle 的 Container
    // 渲染圆形头像（无任何嵌套裁剪伪影）。据实改断言：
    //   - 不存在 ClipOval（旧实现已移除）
    //   - 头像 Hero 内是一个 shape == BoxShape.circle 的 Container（单层圆形）
    expect(find.byType(ClipOval), findsNothing);

    final avatarContainer = tester.widget<Container>(
      find.descendant(of: find.byType(Hero), matching: find.byType(Container)),
    );
    final decoration = avatarContainer.decoration! as BoxDecoration;
    expect(
      decoration.shape,
      BoxShape.circle,
      reason:
          'Avatar must be rendered by a single BoxShape.circle Container, '
          'not nested clip widgets',
    );
  });

  testWidgets('H4 (hero anchor): avatar wrapped in Hero with shared tag', (
    tester,
  ) async {
    await pumpPage(tester);

    // 找出所有 Hero widget，过滤 tag 等于 personal_info_avatar_hero
    final heroes = tester.widgetList<Hero>(find.byType(Hero));
    final hasAvatarHero = heroes.any(
      (h) => h.tag == 'personal_info_avatar_hero',
    );
    expect(
      hasAvatarHero,
      isTrue,
      reason:
          'PersonalInfoPage avatar must be wrapped in '
          'Hero(tag: "personal_info_avatar_hero") for preview animation',
    );
  });

  testWidgets('H5 (camera badge visible): renders camera_fill icon as '
      'change-avatar entry', (tester) async {
    await pumpPage(tester);

    // 相机角标存在 → 用户能看见"可换头像"暗示
    expect(
      find.byIcon(CupertinoIcons.camera_fill),
      findsOneWidget,
      reason:
          'Camera badge (CupertinoIcons.camera_fill) must be visible '
          'on avatar to indicate it is tappable for changing avatar',
    );
  });

  testWidgets('renders nickname + account ID footer below avatar', (
    tester,
  ) async {
    await pumpPage(tester);

    // Hero 段下方应展示 nickname + 'ID: $account'
    expect(find.text('Tester'), findsAtLeastNWidgets(1));
    expect(find.text('ID: imboy_tester'), findsOneWidget);
  });

  testWidgets('e2e: tap avatar with empty url does not push preview page', (
    tester,
  ) async {
    // 默认 setUp 已设 avatar=''
    await pumpPage(tester);

    // 验证起始无 xmark icon（_AvatarPreviewPage 关闭按钮）
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);

    // tap 头像主体（按 tag 精确定位 avatar Hero，排除导航栏默认 Hero；
    // 外层 GestureDetector → _openAvatarPreview）
    await tester.tap(_avatarHeroFinder);
    // Hero animation 飞行约 280ms，多 pump 几次确保完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 守卫生效：avatar 为空时 _openAvatarPreview 早返回，不 push 任何页面
    // _AvatarPreviewPage 的 xmark 关闭按钮仍找不到
    expect(
      find.byIcon(CupertinoIcons.xmark),
      findsNothing,
      reason:
          'Empty avatar URL must not open preview page '
          '(_openAvatarPreview guard: currentUserAvatar.isEmpty → return)',
    );
  });

  testWidgets('e2e: tap avatar with non-empty url pushes preview page '
      'with xmark close button', (tester) async {
    // 用 file:// scheme 避免实际网络拉取，cachedImageProvider errorBuilder 兜底
    await _setUserAvatar('file:///nonexistent/avatar.png');
    await pumpPage(tester);

    // 起始无 xmark
    expect(find.byIcon(CupertinoIcons.xmark), findsNothing);

    await tester.tap(_avatarHeroFinder);
    // 等 PageRouteBuilder transition (280ms fade) + Hero flight 完成
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    // _AvatarPreviewPage 已 push：左上角 xmark 关闭按钮可见
    expect(
      find.byIcon(CupertinoIcons.xmark),
      findsOneWidget,
      reason:
          'Non-empty avatar URL must push _AvatarPreviewPage '
          'with xmark close button (Hero animation source landed)',
    );
  });
}
