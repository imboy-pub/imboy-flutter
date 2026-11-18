import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoNavigationBarBackButton;
import 'package:imboy/page/web_shell/web_shell.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/feature_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';

import 'package:imboy/i18n/strings.g.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/auth_session_scope.dart';

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (uid: 'A', generation: 1, transitioning: false);

  @override
  bool isCurrent(AuthSessionScope captured) =>
      captured == current && current.uid.isNotEmpty && !current.transitioning;

  bool get listening => hasListeners;

  void change(AuthSessionScope next) {
    current = next;
    notifyListeners();
  }
}

void main() {
  Future<(GoRouter, ProviderContainer)> mount(
    WidgetTester tester,
    String location, {
    AuthSessionReader? sessions,
    Widget? child,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/web_shell',
          builder: (_, state) => WebShellRoute(
            uri: state.uri,
            sessionReader: sessions,
            child: child ?? const TextField(key: ValueKey('retained-child')),
          ),
        ),
        GoRoute(path: '/elsewhere', builder: (_, _) => const Text('elsewhere')),
      ],
    );
    addTearDown(router.dispose);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: (_, child) => Material(child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (router, container);
  }

  if (kIsWeb) {
    testWidgets(
      'canonical mobile input projection round-trips without second tab owner',
      (tester) async {
        await tester.runAsync(() async {
          SharedPreferences.setMockInitialValues({
            Keys.currentUid: 'A',
            Keys.currentUser: jsonEncode({'uid': 'A'}),
          });
          await StorageService.init();
        });
        final flags = Map<String, dynamic>.from(AppFeatureRegistry.snapshot);
        addTearDown(() => AppFeatureRegistry.replaceSnapshotForTest(flags));
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(641, 900);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        late BottomNavigationPage projected;
        final (router, container) = await mount(
          tester,
          '/web_shell?tab=mine',
          sessions: _Sessions(),
          child: TranslationProvider(
            child: Consumer(
              builder: (context, ref, _) {
                // Build the real production producer but do not mount its business
                // pages (DB/network). Observe actual controlled inputs/callback only.
                final shell = const WebShellBootstrap().build(
                  context,
                  ref,
                ) as WebShellPage;
                projected = (shell.mobileFallback as ConsumerWidget).build(
                  context,
                  ref,
                ) as BottomNavigationPage;
                return const SizedBox(key: ValueKey('projection-probe'));
              },
            ),
          ),
        );
        expect(
          projected.restoredIndex,
          2,
          reason: 'hidden channel maps mine3 to mobile2',
        );
        final staleMapping = projected.onDestinationSelected!;
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: true});
        expect(
          personalChannelTabAvailable(),
          isTrue,
          reason: 'phase1 profile compiles channel; flag change must alter index meaning',
        );
        staleMapping(2);
        expect(
          container.read(webShellProvider).currentTab,
          3,
          reason:
              'old mobile Mine2 cannot become Channels after feature change',
        );
        AppFeatureRegistry.replaceSnapshotForTest({FeatureKeys.channel: false});
        await tester.pumpAndSettle();
        projected.onDestinationSelected!(1);
        await tester.pumpAndSettle();
        expect(router.routeInformationProvider.value.uri.queryParameters, {
          'tab': 'contact',
        });
        expect(projected.restoredIndex, 1);
        router.go('/web_shell?tab=mine');
        await tester.pumpAndSettle();
        expect(
          projected.restoredIndex,
          2,
          reason: 'route back/reload input updates live',
        );
        final previousOwner = projected.onDestinationSelected!;
        await tester.runAsync(
          () => StorageService.to.setString(Keys.currentUid, 'B'),
        );
        previousOwner(0);
        expect(
          container.read(webShellProvider).currentTab,
          3,
          reason:
              'late callback from previous account must not overwrite route',
        );
        await tester.runAsync(
          () => StorageService.to.setString(Keys.currentUid, 'A'),
        );
        router.go('/web_shell?tab=channel&id=123');
        await tester.pumpAndSettle();
        expect(container.read(webShellProvider).currentTab, 0);
        expect(container.read(webShellProvider).selectedItem, isNull);
        expect(
          router.routeInformationProvider.value.uri.queryParameters['id'],
          isNull,
        );
        expect(
          router.routeInformationProvider.value.uri.queryParameters['tab'],
          'chat',
        );
        expect(tester.takeException(), isNull);
      },
    );

    for (final width in [390.0, 641.0]) {
      for (final tab in ['chat', 'contact']) {
        testWidgets(
          'Browser narrow $width renders $tab deep link and returns',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(width, 900);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetPhysicalSize);
            final (router, container) = await mount(
              tester,
              '/web_shell?tab=$tab&id=9007199254740993&type=C2C',
              sessions: _Sessions(),
              child: WebShellPage(
                tabMessageLabel: 'Messages',
                tabContactLabel: 'Contacts',
                tabChannelLabel: 'Channels',
                tabMineLabel: 'Me',
                welcomeTitle: 'Welcome',
                messageTab: const Text('message list'),
                contactTab: const Text('contact list'),
                channelTab: const Text('channel list'),
                mineTab: const Text('mine list'),
                mobileFallback: const TextField(
                  key: ValueKey('narrow-list-state'),
                ),
                chatBuilder: (sel) => Text('web chat ${sel.peerId}'),
                contactBuilder: (sel) => Text('web contact ${sel.uid}'),
                channelBuilder: (_) => const Text('web channel'),
                mineBuilder: (_) => const Text('web mine'),
              ),
            );
            expect(find.byType(WebMainPanel), findsOneWidget);
            expect(find.text('web $tab 9007199254740993'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('narrow-list-state')),
              findsNothing,
            );
            final retained = tester.element(
              find.byKey(
                const ValueKey('narrow-list-state'),
                skipOffstage: false,
              ),
            );
            await tester.tap(find.byType(CupertinoNavigationBarBackButton));
            await tester.pumpAndSettle();
            expect(container.read(webShellProvider).selectedItem, isNull);
            expect(
              router.routeInformationProvider.value.uri.queryParameters['id'],
              isNull,
            );
            expect(
              find.byKey(const ValueKey('narrow-list-state')),
              findsOneWidget,
            );
            expect(
              tester.element(find.byKey(const ValueKey('narrow-list-state'))),
              same(retained),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('联系人转聊天后地址与选择保持一致且保留宿主', (tester) async {
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=contact&id=9007199254740993',
      sessions: _Sessions(),
    );
    expect(
      container.read(webShellProvider).selectedItem,
      const ContactSelection(uid: '9007199254740993'),
    );
    final child = tester.element(find.byKey(const ValueKey('retained-child')));
    container
        .read(webShellProvider.notifier)
        .openChat(
          const ChatSelection(peerId: '9007199254740993', chatType: 'C2C'),
        );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'tab': 'chat',
      'id': '9007199254740993',
      'type': 'C2C',
    });
    expect(container.read(webShellProvider).currentTab, 0);
    expect(
      container.read(webShellProvider).selectedItem,
      const ChatSelection(peerId: '9007199254740993', chatType: 'C2C'),
    );
    expect(
      tester.element(find.byKey(const ValueKey('retained-child'))),
      same(child),
    );
  });

  testWidgets('deep link restores before showing child', (tester) async {
    final (_, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=peer&type=C2G',
    );
    expect(
      container.read(webShellProvider).selectedItem,
      const ChatSelection(peerId: 'peer', chatType: 'C2G'),
    );
  });

  testWidgets('queued restore discards the previous account route', (
    tester,
  ) async {
    await StorageService.to.setString(Keys.currentUid, 'route-old-account');
    addTearDown(() => StorageService.to.remove(Keys.currentUid));
    tester.binding.addPostFrameCallback((_) {
      unawaited(
        StorageService.to
            .setString(Keys.currentUid, 'route-new-account')
            .then<void>((_) {}),
      );
    });
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=old-peer&type=C2C',
    );
    expect(container.read(webShellProvider), const WebShellState());
    expect(
      router.routeInformationProvider.value.uri.queryParameters['id'],
      isNull,
    );
    expect(find.byKey(const ValueKey('retained-child')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('same UID with a new generation cancels queued restore', (
    tester,
  ) async {
    final sessions = _Sessions();
    addTearDown(sessions.dispose);
    tester.binding.addPostFrameCallback((_) {
      sessions.change((uid: 'A', generation: 2, transitioning: false));
    });
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=old-peer&type=C2C',
      sessions: sessions,
    );
    expect(container.read(webShellProvider), const WebShellState());
    expect(router.routeInformationProvider.value.uri.hasQuery, isFalse);
    expect(find.byKey(const ValueKey('retained-child')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth transition clears context and recovers when settled', (
    tester,
  ) async {
    final sessions = _Sessions();
    addTearDown(sessions.dispose);
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=old-peer&type=C2C',
      sessions: sessions,
    );
    sessions.change((uid: 'A', generation: 2, transitioning: true));
    await tester.pumpAndSettle();
    expect(container.read(webShellProvider), const WebShellState());
    expect(router.routeInformationProvider.value.uri.hasQuery, isFalse);
    expect(find.byKey(const ValueKey('retained-child')), findsNothing);
    sessions.change((uid: 'A', generation: 2, transitioning: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('retained-child')), findsOneWidget);
    expect(container.read(webShellProvider).selectedItem, isNull);
    router.go('/web_shell?tab=contact&id=new-peer');
    await tester.pumpAndSettle();
    expect(
      container.read(webShellProvider).selectedItem,
      const ContactSelection(uid: 'new-peer'),
    );
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    expect(sessions.listening, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departing shell cannot redirect after auth changes', (
    tester,
  ) async {
    final sessions = _Sessions();
    addTearDown(sessions.dispose);
    final (router, _) = await mount(
      tester,
      '/web_shell?tab=chat&id=old-peer&type=C2C',
      sessions: sessions,
    );
    router.go('/elsewhere');
    await tester.pump();
    expect(find.byType(WebShellRoute, skipOffstage: false), findsOneWidget);
    sessions.change((uid: 'B', generation: 2, transitioning: false));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/elsewhere');
    expect(find.text('elsewhere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('departing shell cannot redirect on provider changes', (
    tester,
  ) async {
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=old-peer&type=C2C',
    );
    router.go('/elsewhere');
    await tester.pump();
    expect(find.byType(WebShellRoute, skipOffstage: false), findsOneWidget);
    container
        .read(webShellProvider.notifier)
        .selectItem(const ContactSelection(uid: 'late-peer'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/elsewhere');
    expect(find.text('elsewhere'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shell selection updates URI and retains child', (tester) async {
    final (router, container) = await mount(tester, '/web_shell');
    await tester.enterText(
      find.byKey(const ValueKey('retained-child')),
      'draft',
    );
    final element = tester.element(
      find.byKey(const ValueKey('retained-child')),
    );
    container
        .read(webShellProvider.notifier)
        .selectItem(const ChatSelection(peerId: 'peer:1', chatType: 'C2C'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'tab': 'chat',
      'id': 'peer:1',
      'type': 'C2C',
    });
    expect(
      tester.element(find.byKey(const ValueKey('retained-child'))),
      same(element),
    );
    expect(find.text('draft'), findsOneWidget);
    container.read(webShellProvider.notifier).clearSelection();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.queryParameters, {
      'tab': 'chat',
    });
  });

  testWidgets('route changes restore state without a feedback loop', (
    tester,
  ) async {
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=contact&id=one',
    );
    router.go('/web_shell?tab=chat&id=two&type=C2G');
    await tester.pumpAndSettle();
    expect(
      container.read(webShellProvider).selectedItem,
      const ChatSelection(peerId: 'two', chatType: 'C2G'),
    );
    router.go('/web_shell?tab=contact&id=one');
    await tester.pumpAndSettle();
    expect(
      container.read(webShellProvider).selectedItem,
      const ContactSelection(uid: 'one'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('router delegate history restore updates the same shell', (
    tester,
  ) async {
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=contact&id=one',
    );
    final previous = router.routerDelegate.currentConfiguration;
    final element = tester.element(
      find.byKey(const ValueKey('retained-child')),
    );
    container
        .read(webShellProvider.notifier)
        .selectItem(const ContactSelection(uid: 'two'));
    await tester.pumpAndSettle();
    final forward = router.routerDelegate.currentConfiguration;
    await router.routerDelegate.setNewRoutePath(previous);
    await tester.pumpAndSettle();
    expect(
      container.read(webShellProvider).selectedItem,
      const ContactSelection(uid: 'one'),
    );
    await router.routerDelegate.setNewRoutePath(forward);
    await tester.pumpAndSettle();
    expect(
      container.read(webShellProvider).selectedItem,
      const ContactSelection(uid: 'two'),
    );
    expect(
      tester.element(find.byKey(const ValueKey('retained-child'))),
      same(element),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('invalid type falls back and leaving stops URL writes', (
    tester,
  ) async {
    final (router, container) = await mount(
      tester,
      '/web_shell?tab=chat&id=one&type=invalid',
    );
    expect(container.read(webShellProvider), const WebShellState());
    router.go('/elsewhere');
    await tester.pumpAndSettle();
    container.read(webShellProvider.notifier).switchTab(1);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/elsewhere');
    expect(tester.takeException(), isNull);
  });
}
