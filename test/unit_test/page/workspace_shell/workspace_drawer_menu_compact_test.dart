import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace_shell/workspace_drawer_menu.dart';

import '../../../ux_matrix/ux_harness.dart';
import '../../../uiux/support/golden_font_loader.dart';
import 'workspace_drawer_menu_test.dart';

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double get textScaleFactor => 1;

  @override
  double scale(double fontSize) => fontSize * (fontSize < 20 ? 1.9 : 1.4);
}

void main() {
  setupDrawerTests();

  for (final width in [320.0, 330.0, 340.0, 350.0, 360.0, 390.0]) {
    testWidgets('大字号创建企业入口不孤立末字 ($width)', (tester) async {
      await prepareGoldenFonts(tester);
      await pumpDrawer(
        tester,
        combo: UxCombo(Size(width, 800), textScale: 2),
        golden: true,
      );
      final label = t.workspace.createOrJoinEnterprise;
      final finder = find.text(label);
      await tester.ensureVisible(finder);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: finder, matching: find.byType(RichText)),
      );
      final beforeLast = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: label.length - 2,
          extentOffset: label.length - 1,
        ),
      );
      final last = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: label.length - 1, extentOffset: label.length),
      );
      expect(beforeLast.single.top, last.single.top);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.5, 1.75, 1.8, 1.9, 1.99]) {
      testWidgets('缩放创建企业入口不孤立末字 ($width/$scale)', (tester) async {
        await prepareGoldenFonts(tester);
        await pumpDrawer(
          tester,
          combo: UxCombo(Size(width, 800), textScale: scale),
          golden: true,
        );
        final label = t.workspace.createOrJoinEnterprise;
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        );
        final beforeLast = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: label.length - 2,
            extentOffset: label.length - 1,
          ),
        );
        final last = paragraph.getBoxesForSelection(
          TextSelection(
            baseOffset: label.length - 1,
            extentOffset: label.length,
          ),
        );
        expect(beforeLast.single.top, last.single.top);
      });
    }
  }

  for (final mode in ['bold', 'letter', 'word']) {
    testWidgets('创建企业布局遵循文字无障碍设置 ($mode)', (tester) async {
      await prepareGoldenFonts(tester);
      await pumpDrawer(
        tester,
        combo: UxCombo(Size(320, 800), textScale: mode == 'bold' ? 1.9 : 1.5),
        golden: true,
        boldText: mode == 'bold',
        letterSpacingOverride: mode == 'letter' ? 10 : null,
        wordSpacingOverride: mode == 'word' ? 40 : null,
      );
      final finder = find.text(t.workspace.createOrJoinEnterprise);
      await tester.ensureVisible(finder);
      if (mode == 'bold') {
        final richText = tester.widget<RichText>(
          find.descendant(of: finder, matching: find.byType(RichText)),
        );
        expect((richText.text as TextSpan).style!.fontWeight, FontWeight.bold);
      }
      expect(
        tester
            .getRect(find.byIcon(CupertinoIcons.rectangle_stack_badge_plus))
            .bottom,
        lessThanOrEqualTo(tester.getRect(finder).top),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('创建企业布局按按钮实际继承样式测量', (tester) async {
    await prepareGoldenFonts(tester);
    await pumpDrawer(
      tester,
      combo: const UxCombo(Size(320, 800)),
      golden: true,
      cupertinoTheme: const CupertinoThemeData(
        textTheme: CupertinoTextThemeData(
          actionTextStyle: TextStyle(letterSpacing: 10),
        ),
      ),
    );
    final finder = find.text(t.workspace.createOrJoinEnterprise);
    await tester.ensureVisible(finder);
    expect(
      tester
          .getRect(find.byIcon(CupertinoIcons.rectangle_stack_badge_plus))
          .bottom,
      lessThanOrEqualTo(tester.getRect(finder).top),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('非线性缩放的创建企业入口保留完整文案和操作', (tester) async {
    await prepareGoldenFonts(tester);
    final (_, router, _) = await pumpDrawer(
      tester,
      combo: const UxCombo(Size(320, 800)),
      textScaler: const _NonlinearTextScaler(),
      golden: true,
    );
    final label = t.workspace.createOrJoinEnterprise;
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)),
    );
    expect(
      paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: label.length - 2,
              extentOffset: label.length - 1,
            ),
          )
          .single
          .top,
      paragraph
          .getBoxesForSelection(
            TextSelection(
              baseOffset: label.length - 1,
              extentOffset: label.length,
            ),
          )
          .single
          .top,
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/organization/picker',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('大字号英文创建企业入口保留完整文案和操作', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.enUs);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    await prepareGoldenFonts(tester);
    final (_, router, _) = await pumpDrawer(
      tester,
      combo: const UxCombo(Size(320, 800), textScale: 2),
      golden: true,
    );
    final label = t.workspace.createOrJoinEnterprise;
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: finder, matching: find.byType(RichText)),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.getBoxesForSelection(
        TextSelection(baseOffset: label.length - 1, extentOffset: label.length),
      ),
      isNotEmpty,
    );
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.matches.last.matchedLocation,
      '/organization/picker',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 按内容收缩，不带 Drawer 或满高布局', (tester) async {
    await pumpDrawer(
      tester,
      scenario: 'neutral',
      initialExperience: ProductExperience.personal,
      compact: true,
      compactMaxHeight: 640,
    );
    final menu = find.byType(WorkspaceDrawerMenu);
    expect(find.byType(Drawer), findsNothing);
    expect(
      find.descendant(of: menu, matching: find.byType(IntrinsicHeight)),
      findsNothing,
    );
    expect(
      find.descendant(of: menu, matching: find.byType(Spacer)),
      findsNothing,
    );
    expect(tester.getSize(menu).height, lessThan(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 矮面板与大字可滚动，退出仍需确认', (tester) async {
    var closed = 0;
    await pumpDrawer(
      tester,
      compact: true,
      compactMaxHeight: 260,
      combo: const UxCombo(
        Size(320, 560),
        textScale: 2,
        brightness: Brightness.dark,
      ),
      onClose: () => closed++,
    );
    final menu = find.byType(WorkspaceDrawerMenu);
    final scrollable = find.descendant(
      of: menu,
      matching: find.byType(Scrollable),
    );
    expect(tester.getSize(menu).height, lessThanOrEqualTo(260));
    expect(scrollable, findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(t.account.logOut),
      160,
      scrollable: scrollable,
    );
    await tester.tap(find.text(t.account.logOut));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(menu, findsOneWidget);
    expect(closed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 等待切换期间保留菜单，成功后关闭且保留底页', (tester) async {
    final gate = Completer<void>();
    var closed = 0;
    final experience = DrawerExperience(
      ProductExperience.workspace,
      beforeSelect: () => gate.future,
    );
    final (container, router, _) = await pumpDrawer(
      tester,
      compact: true,
      experienceOverride: experience,
      onClose: () => closed++,
    );
    final personal = find.byKey(const ValueKey('drawer-space-personal'));
    await tester.tap(personal);
    await tester.pump();
    expect(closed, 0);
    expect(
      find.descendant(
        of: personal,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(find.byType(WorkspaceDrawerMenu), findsNothing);
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(
      CurrentOrganizationStore.forAccount(drawerAccount).value?.id,
      '7001',
    );
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 企业切换失败不关闭，也不改变原空间', (tester) async {
    var closed = 0;
    final (container, _, _) = await pumpDrawer(
      tester,
      compact: true,
      initialExperience: ProductExperience.personal,
      httpAdapter: DrawerDetailAdapter(failDetail: true),
      onClose: () => closed++,
    );
    final orgB = find.byKey(const ValueKey('drawer-space-7002'));
    await tester.tap(orgB);
    await tester.pumpAndSettle();
    expect(closed, 0);
    expect(find.byType(WorkspaceDrawerMenu), findsOneWidget);
    expect(
      CurrentOrganizationStore.forAccount(drawerAccount).value?.id,
      '7001',
    );
    expect(
      container.read(productExperienceProvider),
      ProductExperience.personal,
    );
    expect(
      find.descendant(
        of: orgB,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact 资料跳转先关闭自身，返回后不重现旧菜单', (tester) async {
    var closed = 0;
    final (_, router, _) = await pumpDrawer(
      tester,
      compact: true,
      onClose: () => closed++,
    );
    await tester.tap(find.text('合成用户'));
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(find.text('/personal_info/profile'), findsOneWidget);
    expect(find.byType(WorkspaceDrawerMenu), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(router.canPop(), isFalse);
    expect(find.byType(WorkspaceDrawerMenu), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
