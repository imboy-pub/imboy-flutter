import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/presentation/current_space_tile.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/app_sizes.dart';

class _PersonalExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.personal;
}

class _WorkspaceExperience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.workspace;
}

void main() {
  for (final enterprise in [false, true]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('compact space fits $enterprise $scale $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          const enterpriseLabel = '示例企业的较长名称 · 当前工作区的较长名称';
          final label = enterprise
              ? enterpriseLabel
              : t.organization.experienceUi.personalSpace;
          final router = _compactRouter(label);
          addTearDown(router.dispose);
          await tester.pumpWidget(
            _app(router, scale, brightness, enterprise: enterprise),
          );
          await tester.pumpAndSettle();
          final button = find.byKey(const ValueKey('mine-space-switch'));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(tester.widget<Tooltip>(find.byType(Tooltip)).message, label);
          expect(find.text(label), findsOneWidget);
          final semantics = tester.widget<Semantics>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Semantics && widget.properties.value == label,
            ),
          );
          expect(
            semantics.properties.label,
            t.organization.experienceUi.switchSpace,
          );
          expect(semantics.properties.onTap, isNotNull);
          expect(tester.takeException(), isNull);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(find.text('Space picker'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('compact label stays shell-bound while experience updates', (
    tester,
  ) async {
    const label = '当前企业 · 当前工作区';
    final router = _compactRouter(label);
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, 1, Brightness.light));
    await tester.pumpAndSettle();
    expect(find.text(label), findsOneWidget);
    expect(find.text(t.organization.experienceUi.personalSpace), findsNothing);
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    for (final scale in [1.0, 1.3, 2.0, 3.0]) {
      for (final brightness in Brightness.values) {
        testWidgets('space title fits navigation $width $scale $brightness', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final router = _router();
          addTearDown(router.dispose);
          await tester.pumpWidget(_app(router, scale, brightness));
          await tester.pumpAndSettle();
          final title = find.descendant(
            of: find.byType(CurrentSpaceTile),
            matching: find.byType(Text),
          );
          final titleRect = tester.getRect(title);
          final navRect = tester.getRect(find.byType(CupertinoNavigationBar));
          expect(titleRect.top, greaterThanOrEqualTo(navRect.top));
          expect(titleRect.bottom, lessThanOrEqualTo(navRect.bottom));
          expect(titleRect.left, greaterThanOrEqualTo(navRect.left));
          expect(titleRect.right, lessThanOrEqualTo(navRect.right));
          final text = tester.widget<Text>(title);
          expect(text.maxLines, 1);
          expect(text.overflow, TextOverflow.ellipsis);
          await tester.tap(title);
          await tester.pumpAndSettle();
          expect(find.text('Space picker'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

GoRouter _compactRouter(String label) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => Scaffold(
        body: Center(
          child: SizedBox(
            width: AppSizes.avatarSizeXXLarge * 2,
            child: CurrentSpaceTile(compact: true, compactLabel: label),
          ),
        ),
      ),
    ),
    GoRoute(
      path: kOrganizationPickerPath,
      builder: (_, _) => const Scaffold(body: Text('Space picker')),
    ),
  ],
);

GoRouter _router() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const IosPageTemplate(
        title: '频道',
        middle: CurrentSpaceTile(heading: '频道'),
        actions: [Icon(CupertinoIcons.search), Icon(CupertinoIcons.add)],
        body: Center(child: Text('Content')),
      ),
    ),
    GoRoute(
      path: kOrganizationPickerPath,
      builder: (_, _) => const Scaffold(body: Text('Space picker')),
    ),
  ],
);

Widget _app(
  GoRouter router,
  double scale,
  Brightness brightness, {
  bool enterprise = false,
}) => ProviderScope(
  overrides: [
    currentUserProvider.overrideWithValue(null),
    productExperienceProvider.overrideWith(
      enterprise ? _WorkspaceExperience.new : _PersonalExperience.new,
    ),
  ],
  child: TranslationProvider(
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: const EdgeInsets.only(top: 47),
          textScaler: TextScaler.linear(scale),
        ),
        child: child!,
      ),
    ),
  ),
);
