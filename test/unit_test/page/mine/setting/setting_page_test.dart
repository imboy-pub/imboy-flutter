// SettingPage 渲染与偏好域（真实返回上下文/字体缩放/layout/menu/nav/隐私政策
// 契约）；Web 登出撤销域见 setting_page_logout_web_test.dart。
// 拆分自原 setting_page_test.dart（ratchet <800 行约束）。
import 'package:imboy/service/explicit_web_logout.dart';

import 'dart:async';
import 'dart:io';

import 'package:imboy/page/mine/dark_model/dark_model_page.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:imboy/component/ui/ios_settings_ui.dart' show ImBoySettingsTile;
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show appVsn;
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/page/mine/account_security/account_security_page.dart';
import 'package:imboy/page/single/markdown_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'setting_page_support.dart';

void main() {
  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    // 注入 currentUid 让 userRepoProvider 工作
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_001');
    await StorageService.setMap(Keys.currentUser, <String, dynamic>{
      'uid': 'tsid_uid_001',
      'account': 'imboy_user',
      'nickname': 'Tester',
      'avatar': '',
      'email': '',
      'gender': 0,
      'sign': '',
      'region': '',
      'createdAt': 0,
    });
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
    await StorageService.to.remove(Keys.currentUser);
  });

  group('real settings return context', () {
    for (final width in [390.0, 1024.0]) {
      for (final font in [false, true]) {
        testWidgets(
          'real ${font ? 'font' : 'theme'} returns to same entry at $width',
          (tester) async {
            final (scope, router) = await realPreferenceContext(tester, width);
            final page = find.byType(SettingPage);
            final viewport = find.descendant(
              of: page,
              matching: find.byType(CustomScrollView),
            );
            final scrollable = find
                .descendant(of: viewport, matching: find.byType(Scrollable))
                .first;
            final label = font ? t.common.fontSettings : t.main.darkModel;
            final entry = find.descendant(of: page, matching: find.text(label));
            final entryId = font ? 'setting:/font_size' : 'setting:/dark_model';
            await tester.drag(viewport, const Offset(0, -100));
            await tester.pumpAndSettle();
            final beforeState = tester.state(page);
            final beforeElement = tester.element(entry);
            final position = tester.state<ScrollableState>(scrollable).position;
            expect(
              position.pixels,
              greaterThan(0),
              reason: '$entryId must be scrolled',
            );
            final beforeY =
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy;
            expect(beforeY, greaterThanOrEqualTo(0));
            final beforeFont = tester
                .renderObject<RenderParagraph>(
                  find.descendant(of: entry, matching: find.byType(RichText)),
                )
                .text
                .style!
                .fontSize!;
            await tester.tap(entry);
            await tester.pumpAndSettle();
            expect(router.state.uri.path, font ? '/font_size' : '/dark_model');
            if (font) {
              expect(find.byType(FontSizePage), findsOneWidget);
              await chooseRealFont(tester, scope, FontSizeOption.huge);
            } else {
              expect(find.byType(DarkModelPage), findsOneWidget);
              final dark = find.descendant(
                of: find.byType(ImBoySettingsTile),
                matching: find.text(t.main.darkModel),
              );
              await preferenceGesture(tester, scope, () => tester.tap(dark));
              expect(scope.read(themeModeProvider), ThemeMode.dark);
              expect(
                Theme.of(tester.element(find.byType(DarkModelPage))).brightness,
                Brightness.dark,
              );
            }
            await tester.tap(find.byType(GlassBackButton));
            await tester.pumpAndSettle();
            expect(router.state.uri.path, '/setting');
            expect(tester.state(page), same(beforeState));
            expect(tester.element(entry), same(beforeElement));
            expect(position.pixels, greaterThan(0));
            final relativeY =
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy;
            expect(
              relativeY,
              closeTo(beforeY, font ? AppSizes.touchTarget * 2 : 1),
              reason:
                  '$entryId: theme1px/font96px tolerance — 010eef3f9 在设置页上方新增原生个人历史入口后，'
                  '超大字体下上方内容膨胀使返回位移超过旧 48px 标定（实测 61px）；不变量仍为返回后同一入口在视口内',
            );
            final bounds = tester.getRect(viewport),
                item = tester.getRect(entry);
            expect(item.top, greaterThanOrEqualTo(bounds.top));
            expect(item.bottom, lessThanOrEqualTo(bounds.bottom));
            if (font) {
              final rendered = tester
                  .renderObject<RenderParagraph>(
                    find.descendant(of: entry, matching: find.byType(RichText)),
                  )
                  .text
                  .style!
                  .fontSize!;
              expect(
                rendered,
                greaterThan(beforeFont),
                reason: 'actual settings font changed',
              );
              await tester.tap(entry);
              await tester.pumpAndSettle();
              await chooseRealFont(tester, scope, FontSizeOption.normal);
              await tester.tap(find.byType(GlassBackButton));
              await tester.pumpAndSettle();
              expect(tester.state(page), same(beforeState));
              expect(
                tester.getTopLeft(entry).dy - tester.getTopLeft(viewport).dy,
                closeTo(beforeY, 1),
                reason: 'normal geometry returns within1px',
              );
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('logout dialog app font and independent system scale', () {
    for (final appFont in [FontSizeOption.normal, FontSizeOption.huge]) {
      for (final systemScale in [1.0, 2.0]) {
        for (final followAppFont in [true, false]) {
          testWidgets('$appFont system=$systemScale appFont=$followAppFont', (
            tester,
          ) async {
            Future<bool?>? result;
            await tester.pumpWidget(
              TranslationProvider(
                child: MaterialApp(
                  theme: AppTheme.getLightThemeFromOption(appFont),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(systemScale)),
                    child: child!,
                  ),
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () {
                          result = confirmExplicitWebLogout(
                            context,
                            followAppFont: followAppFont,
                          );
                        },
                        child: const Text('open logout dialog'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('open logout dialog'));
            await tester.pumpAndSettle();
            final scale = followAppFont ? appFont.scale : 1.0;
            for (final entry in {
              t.account.logOut: 17.0,
              t.account.areYouSureLogOut: 13.0,
              t.common.buttonCancel: followAppFont ? 17.0 : 16.8,
              t.common.buttonConfirm: followAppFont ? 17.0 : 16.8,
            }.entries) {
              final text = find.descendant(
                of: find.byType(CupertinoAlertDialog),
                matching: find.text(entry.key),
              );
              expect(text, findsOneWidget);
              final paragraph = tester.renderObject<RenderParagraph>(
                find.descendant(of: text, matching: find.byType(RichText)),
              );
              expect(
                paragraph.text.style!.fontSize,
                closeTo(entry.value * scale, 0.001),
              );
              expect(
                paragraph.textScaler.scale(entry.value * scale),
                closeTo(entry.value * scale * systemScale, 0.001),
              );
            }
            for (final action in tester.widgetList<CupertinoDialogAction>(
              find.byType(CupertinoDialogAction),
            )) {
              expect(
                action.textStyle?.fontSize,
                followAppFont ? closeTo(17 * scale, 0.001) : isNull,
              );
              expect(action.textStyle?.color, isNull);
              expect(action.textStyle?.fontWeight, isNull);
            }
            // RenderParagraph scaler is observed above; SDK may fit regular
            // actions and uses wrapping in accessibility mode. Never infer
            // final painted size only from the requested system scale.
            for (final action
                in find.byType(CupertinoDialogAction).evaluate()) {
              final bounds = tester.getRect(
                find.byElementPredicate(
                  (element) => identical(element, action),
                ),
              );
              expect(bounds.width, greaterThan(0));
              expect(bounds.height, greaterThan(0));
            }
            await tester.tap(find.text(t.common.buttonCancel));
            await tester.pumpAndSettle();
            expect(await result, isFalse);
            expect(find.byType(CupertinoAlertDialog), findsNothing);
            expect(tester.takeException(), isNull);
            await unmountSettingPage(tester);
          });
        }
      }
    }
  });

  group('SettingPage layout', () {
    testWidgets('宽窗口内容列居中，版本信息随大字号移到标题下方', (tester) async {
      final previousVersion = appVsn;
      appVsn = '1.2.3+456';
      addTearDown(() => appVsn = previousVersion);
      await pumpSettingPage(tester, width: 1280, scale: 2);

      final scrollRect = tester.getRect(find.byType(CustomScrollView));
      expect(scrollRect.width, ResourcePageLayout.maxWidth);
      expect(scrollRect.center.dx, 640);
      await tester.scrollUntilVisible(find.text(t.common.aboutApp), 220);
      final titleRect = tester.getRect(find.text(t.common.aboutApp));
      final versionRect = tester.getRect(
        find.text('${t.common.version} $appVsn'),
      );
      expect(versionRect.top, greaterThanOrEqualTo(titleRect.bottom));
      expect(versionRect.right, lessThanOrEqualTo(scrollRect.right));
      expect(tester.takeException(), isNull);
      await unmountSettingPage(tester);
    });

    testWidgets('Scaffold uses iOS surfaceGrouped background', (tester) async {
      await pumpSettingPage(tester);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, AppColors.lightSurfaceGrouped);
      await unmountSettingPage(tester);
    });

    testWidgets('AppBar title 渲染 "设置"', (tester) async {
      await pumpSettingPage(tester);
      // i18n zhCn: setting = "设置"
      expect(find.text('设置'), findsAtLeastNWidgets(1));
      await unmountSettingPage(tester);
    });

    testWidgets('Section header "通用" 大写渲染', (tester) async {
      await pumpSettingPage(tester);
      // _buildSectionHeader 用 toUpperCase()，中文 toUpperCase() 不变 → "通用"
      expect(find.text('通用'), findsOneWidget);
      await unmountSettingPage(tester);
    });
  });

  group('SettingPage menu items', () {
    testWidgets('renders 通用 section 5 个菜单项（含企业切换）', (tester) async {
      await pumpSettingPage(tester);

      // 4 个 setting items 主标题
      expect(find.text('账号安全'), findsOneWidget);
      expect(find.text('语言设置'), findsOneWidget);
      expect(find.text('深色模式'), findsOneWidget);
      // fontSettings = @:fontSizeSetting 别名 → 解析为 "字体大小设置"
      expect(find.byIcon(CupertinoIcons.textformat), findsOneWidget);
      expect(find.text('切换空间'), findsOneWidget);

      await unmountSettingPage(tester);
    });

    testWidgets('帮助、账号检查与退出入口仍完整保留', (tester) async {
      await pumpSettingPage(tester);
      // 010eef3f9 在设置页上方加入原生个人历史入口后，页面变长；惰性 sliver 下
      // 底部条目（注销前检查等）在固定画布内不再构建，需先滚动入视口再断言。
      await tester.scrollUntilVisible(
        find.text(t.organization.experienceUi.accountCheck),
        220,
        scrollable: find
            .descendant(
              of: find.byType(SettingPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      for (final label in [
        t.common.helpDocument,
        t.common.updateLog,
        t.main.privacyPolicy,
        t.main.termsOfService,
        t.common.aboutApp,
        t.account.logOut,
        t.organization.experienceUi.accountCheck,
        t.account.logoutAccount,
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      await unmountSettingPage(tester);
    });
  });

  group('SettingPage navigation', () {
    testWidgets('模式入口统一进入企业选择页，不再提供旧布局及部署默认值', (tester) async {
      await pumpSettingPage(tester);
      expect(find.text('首页布局'), findsNothing);
      expect(find.text('恢复部署默认值'), findsNothing);
      await tester.tap(find.text('切换空间'));
      await tester.pumpAndSettle();
      expect(find.text('organization picker stub'), findsOneWidget);
      await unmountSettingPage(tester);
    });

    testWidgets('tap "账号安全" → /account_security', (tester) async {
      await pumpSettingPage(tester);

      await tester.tap(find.text('账号安全'));
      await tester.pumpAndSettle();
      expect(find.text('account_security stub'), findsOneWidget);
      await unmountSettingPage(tester);
    });

    testWidgets('tap "语言设置" → /language', (tester) async {
      await pumpSettingPage(tester);

      await tester.tap(find.text('语言设置'));
      await tester.pumpAndSettle();
      expect(find.text('language stub'), findsOneWidget);
      await unmountSettingPage(tester);
    });

    testWidgets('tap "深色模式" → /dark_model', (tester) async {
      await pumpSettingPage(tester);

      await tester.tap(find.text('深色模式'));
      await tester.pumpAndSettle();
      expect(find.text('dark_model stub'), findsOneWidget);
      await unmountSettingPage(tester);
    });
  });

  test(
    'shared explicit Web action refuses late confirmation after owner change',
    () async {
      final previousUid = UserRepoLocal.to.currentUid;
      final previousDid = init.deviceId;
      await StorageService.to.setString(Keys.currentUid, '900001');
      init.deviceId = 'web_synthetic_action';
      final confirmation = Completer<bool?>();
      var revokes = 0;
      var quits = 0;
      final action = ExplicitWebLogoutAction(
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) async {
          guard();
          revokes++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
        isLoggedOutAfter: (_) => false,
      );
      try {
        final run = action.run(
          isMounted: () => true,
          confirm: () => confirmation.future,
          onFailure: () {},
        );
        await Future<void>.delayed(Duration.zero);
        await StorageService.to.setString(Keys.currentUid, '900002');
        confirmation.complete(true);
        expect(await run, isFalse);
        expect(revokes, 0);
        expect(quits, 0);
      } finally {
        await StorageService.to.setString(Keys.currentUid, previousUid);
        init.deviceId = previousDid;
      }
    },
  );

  test('shared explicit Web action coalesces repeated entry and revokes before local', () async {
    final previousUid = UserRepoLocal.to.currentUid;
    final previousDid = init.deviceId;
    await StorageService.to.setString(Keys.currentUid, '900001');
    init.deviceId = 'web_synthetic_action';
    final revocation = Completer<bool>();
    final events = <String>[];
    final action = ExplicitWebLogoutAction(
      readWebDeviceId: () async => init.deviceId,
      revokeWebDevice: (_, guard) async {
        guard();
        events.add('revoke');
        return revocation.future;
      },
      quitLocal: (_) async {
        events.add('quit');
        return true;
      },
      isLoggedOutAfter: (_) => true,
    );
    try {
      final run = action.run(
        isMounted: () => true,
        confirm: () async => true,
        onFailure: () {},
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        await action.run(
          isMounted: () => true,
          confirm: () async => true,
          onFailure: () {},
        ),
        isFalse,
      );
      expect(events, ['revoke']);
      revocation.complete(true);
      expect(await run, isTrue);
      expect(events, ['revoke', 'quit']);
    } finally {
      await StorageService.to.setString(Keys.currentUid, previousUid);
      init.deviceId = previousDid;
    }
  });

  group('隐私政策与联系入口契约（UX-03:LOCAL:01/02）', () {
    final contactPattern = RegExp(
      r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
      r'|1[3-9]\d{9}'
      r'|mailto:'
      r'|tel:',
    );

    testWidgets('隐私政策与服务条款入口可达：政策走离线审定文档，条款走注册路由', (tester) async {
      await pumpSettingPage(tester);
      await tester.scrollUntilVisible(find.text(t.main.privacyPolicy), 220);

      await tester.tap(find.text(t.main.privacyPolicy));
      await tester.pumpAndSettle();
      final policy = tester.widget<MarkdownPage>(find.byType(MarkdownPage));
      expect(policy.url, 'asset://docs/privacy-policy.md');
      expect(policy.title, t.main.privacyPolicy);
      // 联系渠道（第 9 节）随政策文档一起可发现，本页不自行另设联系方式
      await tester.tap(find.byType(GlassBackButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.main.termsOfService));
      await tester.pumpAndSettle();
      expect(find.text('terms_of_service stub'), findsOneWidget);

      await unmountSettingPage(tester);
    });

    testWidgets('设置页不擅自填充联系方式（渲染面无任何联系方式字面量）', (tester) async {
      await pumpSettingPage(tester);
      // 顶部（通用+隐私安全 section）
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final content = text.data ?? '';
        expect(
          contactPattern.hasMatch(content),
          isFalse,
          reason: '设置页渲染面不得出现自填联系方式（发现: "$content"）',
        );
      }
      // 滚到底部（帮助/环境/退出 section）再扫一遍
      await tester.scrollUntilVisible(find.text(t.account.logOut), 220);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final content = text.data ?? '';
        expect(
          contactPattern.hasMatch(content),
          isFalse,
          reason: '设置页渲染面不得出现自填联系方式（发现: "$content"）',
        );
      }

      await unmountSettingPage(tester);
    });

    testWidgets('账号安全页绑定信息脱敏显示，不泄漏原始联系方式', (tester) async {
      final previousUser = StorageService.getMap(Keys.currentUser);
      await StorageService.setMap(Keys.currentUser, {
        ...previousUser,
        'email': 'person@example.com',
        'mobile': '13800138000',
      });
      addTearDown(() async {
        await StorageService.setMap(Keys.currentUser, previousUser);
        UserRepoLocal.to.notifyListeners();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: TranslationProvider(
            child: MaterialApp(home: AccountSecurityPage()),
          ),
        ),
      );
      await tester.pump();

      // 原始联系方式不得明文出现
      expect(
        find.text('person@example.com'),
        findsNothing,
        reason: '原始邮箱不得明文显示',
      );
      expect(find.text('13800138000'), findsNothing, reason: '原始手机号不得明文显示');
      // 只出现脱敏形态
      expect(find.textContaining('pe***@example.com'), findsOneWidget);
      expect(find.textContaining('138****8000'), findsOneWidget);
      // 凭据/权利管理入口完整在场
      expect(find.text(t.account.bindEmail), findsOneWidget);
      expect(find.text(t.account.bindMobile), findsOneWidget);
      expect(find.text(t.account.bindAlipay), findsOneWidget);
      expect(find.text(t.account.changeLoginPassword), findsOneWidget);

      await unmountSettingPage(tester);
    });

    test('三个在册页面源码均不硬编码联系方式字面量（含未渲染分支）', () {
      // 无引号锚点的强负例：邮箱/CN 手机号字面量在任何位置（含注释）出现
      // 都算自填联系方式；本断言比“仅字符串字面量内”更严格。
      final literalPattern = RegExp(
        r'mailto:|tel:[0-9]'
        r'|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
        r'|1[3-9]\d{9}',
      );
      for (final path in [
        'lib/page/mine/setting/setting_page.dart',
        'lib/page/personal_info/profile/widgets/privacy_settings_page.dart',
        'lib/page/mine/account_security/account_security_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(
          literalPattern.hasMatch(source),
          isFalse,
          reason: '$path 不得硬编码联系方式；联系渠道由外部审定的政策文档承载',
        );
      }
    });
  });
}
