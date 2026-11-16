@TestOn('chrome')
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/passport/web_login_page.dart';
import 'package:imboy/page/splash/splash_page.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/router/app_router.dart';
import 'package:imboy/run.dart';
import 'package:imboy/service/deep_link_router_bridge.dart';
import 'package:imboy/service/incoming_backup_handler.dart';
import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:imboy/modules/talk_record/application/talk_record_recording_coordinator.dart';
import 'package:imboy/modules/talk_record/presentation/talk_record_providers.dart';

import '../../../fixtures/web_profile_io_fence.dart';

class _FontEndpoint implements Env {
  const _FontEndpoint(this.apiBaseUrl);
  @override
  final String apiBaseUrl;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StartupExperience extends ProductExperienceNotifier {
  _StartupExperience(this.value);
  final ProductExperience value;
  @override
  ProductExperience build() => value;
}

void main() {
  GoRouter router() => GoRouter(
    initialLocation: '/native-hook-a',
    routes: [
      for (final suffix in ['a', 'b'])
        GoRoute(
          path: '/native-hook-$suffix',
          builder: (_, _) => Scaffold(body: Text('native-hook-$suffix')),
        ),
    ],
  );

  for (final width in [641.0, 900.0]) {
    testWidgets('production signin builder keeps Browser Web auth at $width', (
      tester,
    ) async {
      final fence = ProfileIoFence()..install();
      addTearDown(fence.verifyAndRestore);
      final production = createAppRouter(navigatorKeyOverride: GlobalKey());
      addTearDown(production.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final route = production.configuration.routes
          .whereType<GoRoute>()
          .singleWhere((route) => route.path == '/sign_in');
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final page = route.pageBuilder!(
                context,
                GoRouterState(
                  production.configuration,
                  uri: Uri.parse('/sign_in'),
                  matchedLocation: '/sign_in',
                  fullPath: '/sign_in',
                  pathParameters: const {},
                  pageKey: const ValueKey('signin-builder'),
                ),
              ) as CupertinoPage;
              expect(page.child, isA<WebLoginPage>());
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
    for (final experience in ProductExperience.values) {
      testWidgets('production root splash $experience at $width', (
        tester,
      ) async {
        final fence = ProfileIoFence()..install();
        addTearDown(fence.verifyAndRestore);
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({Keys.currentUid: '990091'});
          await StorageService.init();
        });
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final production = createAppRouter(navigatorKeyOverride: GlobalKey());
        final root = production.configuration.routes
            .whereType<GoRoute>()
            .singleWhere((route) => route.path == '/');
        final routes = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', pageBuilder: root.pageBuilder),
            for (final target in ['/web_shell', '/bottom_navigation'])
              GoRoute(
                path: target,
                builder: (_, _) => Scaffold(body: Text(target)),
              ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          routes.dispose();
          production.dispose();
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              productExperienceProvider.overrideWith(
                () => _StartupExperience(experience),
              ),
            ],
            child: TranslationProvider(
              child: MaterialApp.router(routerConfig: routes),
            ),
          ),
        );
        await tester.pump(kSplashMinHoldReturning);
        await tester.pumpAndSettle();
        final expected =
            experience == ProductExperience.personal || width >= 900
            ? '/web_shell'
            : '/bottom_navigation';
        expect(routes.routeInformationProvider.value.uri.path, expected);
        expect(find.text(expected), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      });
    }
  }

  test(
    'Web startup does not construct an unsupported native push plugin',
    () async {
      expect(kIsWeb, isTrue);
      final wiring = JPushSdkWiring();
      expect(defaultJPushEnabledCheck(), isFalse);
      await wiring.initialize();
    },
  );

  test('Web does not subscribe to Android deep-link channels', () async {
    final routes = router();
    addTearDown(routes.dispose);
    DeepLinkRouterBridge.watchIncomingLinks(routes);
    await DeepLinkRouterBridge.consumeInitialLink(routes);
  });

  test('Web native backup ingress is an empty closed source', () async {
    expect(await IncomingBackupHandler.consumeInitialFile(), isNull);
    expect(await IncomingBackupHandler.watchIncomingFiles().toList(), isEmpty);
  });

  testWidgets('actual Web app retains platform route-information delivery', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    final routes = router();
    addTearDown(routes.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [goRouterProvider.overrideWithValue(routes)],
        child: const IMBoyApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('native-hook-a'), findsOneWidget);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          SystemChannels.navigation.name,
          SystemChannels.navigation.codec.encodeMethodCall(
            const MethodCall('pushRouteInformation', <String, Object?>{
              'location': '/native-hook-b',
              'state': null,
            }),
          ),
          null,
        );
    await tester.pumpAndSettle();
    expect(find.text('native-hook-b'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'actual Web app follows account font after anonymous startup and replacement',
    (tester) async {
      final fence = ProfileIoFence()..install();
      addTearDown(fence.verifyAndRestore);
      final environment = init.currentEnv;
      final previousEnvironment = envMap[environment];
      final ready = await tester.runAsync(() async {
        SharedPreferences.setMockInitialValues({'theme_font_size': 'huge'});
        await StorageService.init();
        await prepareWebWriter();
        return isWebWriterReady;
      });
      expect(tester.takeException(), isNull);
      expect(ready, isTrue);
      final routes = router();
      // Font ownership must not initialize the unrelated microphone/DB runtime.
      final recording = Completer<TalkRecordRecordingCoordinator>();
      final container = ProviderContainer(
        overrides: [
          goRouterProvider.overrideWithValue(routes),
          talkRecordRecordingRuntimeProvider.overrideWith(
            (_) => recording.future,
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        container.dispose();
        routes.dispose();
        if (previousEnvironment == null) {
          envMap.remove(environment);
        } else {
          envMap[environment] = previousEnvironment;
        }
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const IMBoyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('native-hook-a'), findsOneWidget);
      final theme = container.read(themeProvider.notifier);
      // Drain the actual restore queue in the same real zone as its first frame.
      Future<void> publishProfile() async {
        await tester.runAsync(() async {
          container.invalidate(currentUserProvider);
          await tester.pump();
          await theme.restoreAccountFontSize('', isCurrent: () => false);
        });
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
      }

      // Controlled profile inputs; session writes and notifications have separate tests.
      Future<void> profile(String uid, Map<String, dynamic>? setting) async {
        await tester.runAsync(() async {
          await StorageService.to.setString(Keys.currentUid, uid);
          expect(
            await StorageService.setMap(Keys.currentUser, {
              'uid': uid,
              if (setting != null) 'setting': setting,
            }),
            isTrue,
          );
        });
        await publishProfile();
      }

      double renderedFont() =>
          Theme.of(tester.element(find.text('native-hook-a')))
              .textTheme
              .bodyMedium!
              .fontSize!;
      await profile('990081', {'font_size': 'small'});
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.small,
      );
      final small = renderedFont();
      await tester.runAsync(
        () => theme.updateFontSizeOption(FontSizeOption.huge),
      );
      await tester.pumpAndSettle();
      final huge = renderedFont();
      expect(huge, greaterThan(small));
      // The anonymous first build must not consume a process-global font latch.
      await profile('990082', null);
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.huge,
        reason: 'thin B profile must wait for the real setting map',
      );
      await profile('990082', {});
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.normal,
      );
      expect(renderedFont(), allOf(greaterThan(small), lessThan(huge)));
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('theme_font_size'),
        'huge',
        reason: 'B empty setting uses normal without adopting or rewriting A fallback',
      );
      await profile('990083', null);
      await tester.runAsync(
        () => theme.updateFontSizeOption(FontSizeOption.small),
      );
      await tester.pumpAndSettle();
      await profile('990083', {'font_size': 'large'});
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.small,
        reason: 'current account manual choice wins while its setting is still arriving',
      );
      // A late profile cannot affect the current owner even with valid model data.
      expect(
        await tester.runAsync(
          () => StorageService.setMap(Keys.currentUser, {
            'uid': '990081',
            'setting': {'font_size': 'huge'},
          }),
        ),
        isTrue,
      );
      await publishProfile();
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.small,
      );
      // Same UID on a new endpoint is a new font owner, not an old manual lock.
      envMap[environment] = const _FontEndpoint('http://127.0.0.1:19882');
      await profile('990083', {'font_size': 'large'});
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.large,
      );
      expect(renderedFont(), greaterThan(small));
    },
  );
}
