// Run on a real Android device, without production bootstrap or credentials:
// flutter test integration_test/mine_layout_smoke_test.dart \
//   -d <real-device> --flavor <available-isolated-flavor> --no-pub
// This proves component rendering/navigation with synthetic fixtures only.
// Route destinations are stubs; it does not certify business E2E acceptance.
// Verify the selected flavor's applicationId and process occupancy first.
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_workspace_routes.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/mine/mine/mine_page.dart';
import 'package:imboy/page/mine/mine/mine_shortcut.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import '../test/env_test_pin.dart';

const _fixtureUid = '7266418340025468900';
final _screen = GlobalKey();

/// The adapter also makes unexpected app HTTP calls fail the test.
class _SeatFixtureAdapter implements HttpClientAdapter {
  bool eligible = false;
  final unexpectedPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path != '/api/v1/cs/me/seat-contexts') {
      unexpectedPaths.add(options.path);
      throw StateError('Unexpected HTTP request: ${options.path}');
    }
    return ResponseBody.fromString(
      jsonEncode({
        'code': 0,
        'payload': {
          'contexts': [
            if (eligible)
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

/// Covers accidental raw HTTP outside the app's Dio adapter as well.
class _DenyNetwork extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) =>
      throw StateError('Network access is forbidden in the Mine UI fixture');
}

class _FixtureExperience extends ProductExperienceNotifier {
  _FixtureExperience(this.experience);
  final ProductExperience experience;

  @override
  ProductExperience build() => experience;
}

GoRouter _router({required bool enterprise, String? enterpriseEntry}) {
  Widget target(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/mine',
    routes: [
      GoRoute(
        path: '/mine',
        builder: (context, _) => MinePage(
          enterprise: enterprise,
          enterpriseName: enterprise ? '示例企业' : null,
          enterpriseWorkspaceName: enterprise ? '产品工作区' : null,
          enterpriseEntry: enterpriseEntry == null
              ? null
              : MineShortcut(
                  label: enterpriseEntry,
                  icon: CupertinoIcons.building_2_fill,
                  onTap: () => context.push('/organization-target'),
                ),
        ),
      ),
      for (final path in [
        kOrganizationPickerPath,
        '/personal_info/profile',
        '/qrcode/user',
        '/favorites',
        '/wallet',
        '/storage_space',
        '/devices',
        '/mine/appeal',
        '/mine/setting',
        '/feedback',
        '/organization-target',
        kCsWorkspacePath,
      ])
        GoRoute(path: path, builder: (_, _) => target('destination:$path')),
      GoRoute(
        path: kTalkRecordListPath,
        builder: (_, state) => target('talk:${state.uri.query}'),
      ),
    ],
  );
}

Future<GoRouter> _pumpMine(
  WidgetTester tester, {
  bool enterprise = false,
  String? enterpriseEntry,
  Brightness brightness = Brightness.light,
}) async {
  final router = _router(
    enterprise: enterprise,
    enterpriseEntry: enterpriseEntry,
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel.fromJson({
            'uid': _fixtureUid,
            'nickname': '示例用户',
            'account': '10001',
            'avatar': '',
          }),
        ),
        productExperienceProvider.overrideWith(
          () => _FixtureExperience(
            enterprise
                ? ProductExperience.workspace
                : ProductExperience.personal,
          ),
        ),
      ],
      child: TranslationProvider(
        child: RepaintBoundary(
          key: _screen,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(brightness: brightness),
            // Both production shells provide a Material/Scaffold ancestor.
            builder: (_, child) => Material(child: child),
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Rendered PNG goes through stdout, never device storage or a repository.
/// Each chunk carries its offset so host-side capture can verify completeness.
Future<void> takeScreenshot(WidgetTester tester, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_screen),
  );
  final image = await boundary.toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final encoded = base64Encode(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('[MINE_PNG_BEGIN:$name:${encoded.length}]');
    for (var offset = 0; offset < encoded.length; offset += 800) {
      // ignore: avoid_print
      print(
        '[MINE_PNG:$name:$offset]'
        '${encoded.substring(offset, math.min(offset + 800, encoded.length))}',
      );
    }
    // ignore: avoid_print
    print('[MINE_PNG_END:$name:${encoded.length}]');
  } finally {
    image.dispose();
  }
}

Future<void> _tapTarget(
  WidgetTester tester,
  GoRouter router,
  Finder source,
  String destination,
) async {
  await tester.ensureVisible(source);
  await tester.tap(source);
  await tester.pumpAndSettle();
  expect(find.text(destination), findsOneWidget);
  router.pop();
  await tester.pumpAndSettle();
}

/// A native async response can finish while Flutter has no scheduled frames.
Future<void> _waitFor(WidgetTester tester, Finder target) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!tester.any(target)) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for $target');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final adapter = _SeatFixtureAdapter();
  final previousHttpOverrides = io.HttpOverrides.current;

  setUpAll(() {
    pinLoopbackTestEnv();
    io.HttpOverrides.global = _DenyNetwork();
    app_http.HttpClient.adapterForTest = adapter;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await StorageService.init();
    LocaleSettings.setLocale(AppLocale.zhCn);
    AppFeatureRegistry.replaceSnapshotForTest({
      for (final feature in compiledProductFeatures) feature: true,
    });
    adapter.eligible = false;
    adapter.unexpectedPaths.clear();
  });

  tearDown(() {
    expect(adapter.unexpectedPaths, isEmpty);
    CurrentOrganizationStore.disposeAccount(_fixtureUid);
    AppFeatureRegistry.replaceSnapshotForTest({});
  });

  tearDownAll(() {
    app_http.HttpClient.adapterForTest = null;
    io.HttpOverrides.global = previousHttpOverrides;
  });

  for (final brightness in Brightness.values) {
    testWidgets('personal Mine ${brightness.name}: compact layout and taps', (
      tester,
    ) async {
      adapter.eligible = true;
      final router = await _pumpMine(tester, brightness: brightness);
      await _waitFor(tester, find.text(t.customerService.entryTitle));
      expect(find.text('示例用户'), findsOneWidget);
      expect(find.text('ID: 10001'), findsOneWidget);
      expect(
        find.text(t.organization.experienceUi.personalSpace),
        findsOneWidget,
      );
      expect(find.text(t.organization.experienceUi.currentSpace), findsNothing);
      expect(find.text(t.organization.experienceUi.switchSpace), findsNothing);
      expect(find.text(t.discovery.myChannels), findsNothing);
      expect(find.text(t.main.favorites), findsOneWidget);
      expect(find.text(t.talkRecord.entryTitle), findsOneWidget);
      expect(find.text(t.attachmentManager.personalTitle), findsOneWidget);
      expect(find.text(t.customerService.entryTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await takeScreenshot(tester, 'mine_personal_${brightness.name}');
      for (final entry in <(Finder, String)>[
        (
          find.byKey(const ValueKey('mine-space-switch')),
          kOrganizationPickerPath,
        ),
        (find.byKey(const ValueKey('mine-profile')), '/personal_info/profile'),
        (find.byKey(const ValueKey('mine-qrcode')), '/qrcode/user'),
        (find.text(t.main.favorites), '/favorites'),
        (find.text(t.customerService.entryTitle), kCsWorkspacePath),
        (find.text(t.main.setting), '/mine/setting'),
        (find.text(t.common.feedback), '/feedback'),
      ]) {
        await _tapTarget(tester, router, entry.$1, 'destination:${entry.$2}');
      }
      await tester.ensureVisible(find.text(t.talkRecord.entryTitle));
      await tester.tap(find.text(t.talkRecord.entryTitle));
      await tester.pumpAndSettle();
      expect(find.text('talk:scope=personal'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('enterprise Mine ${brightness.name}: one context and entries', (
      tester,
    ) async {
      final router = await _pumpMine(
        tester,
        enterprise: true,
        enterpriseEntry: t.organization.manage.entry,
        brightness: brightness,
      );
      expect(find.text('示例企业 · 产品工作区'), findsOneWidget);
      expect(find.text(t.organization.experienceUi.currentSpace), findsNothing);
      expect(find.text(t.organization.experienceUi.switchSpace), findsNothing);
      expect(find.text(t.customerService.entryTitle), findsNothing);
      expect(find.text(t.talkRecord.entryTitle), findsNothing);
      expect(find.text(t.attachmentManager.personalTitle), findsNothing);
      expect(find.text(t.main.favorites), findsOneWidget);
      expect(find.text(t.organization.manage.entry), findsOneWidget);
      expect(tester.takeException(), isNull);
      await takeScreenshot(tester, 'mine_enterprise_${brightness.name}');
      await _tapTarget(
        tester,
        router,
        find.byKey(const ValueKey('mine-space-switch')),
        'destination:$kOrganizationPickerPath',
      );
      await _tapTarget(
        tester,
        router,
        find.text(t.organization.manage.entry),
        'destination:/organization-target',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
