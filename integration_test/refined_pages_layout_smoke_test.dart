// Synthetic component verification on a real Android device; no main.dart.
// Build this target with --flavor gzCustomer, install the owned APK with
// adb install --no-streaming, then use the existing IntegrationDriver.
// Verify device/package occupancy first. This is not business E2E acceptance.
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
import 'package:imboy/component/http/http_client.dart' as app_http;
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/attachments/personal_attachment_repository.dart';
import 'package:imboy/modules/attachments/personal_attachments_page.dart';
import 'package:imboy/modules/organization/infrastructure/current_organization_store.dart';
import 'package:imboy/modules/organization/infrastructure/organization_cache.dart';
import 'package:imboy/modules/organization/presentation/organization_picker_page.dart';
import 'package:imboy/modules/organization/presentation/organization_routes.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
import 'package:imboy/page/personal_info/profile/profile_page.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/theme/default/theme.dart';
import 'package:imboy/theme/providers/theme_provider.dart';

import '../test/env_test_pin.dart';

const _uid = '7266418340025468990';
final _screen = GlobalKey();
final _user = UserModel(uid: _uid, account: 'synthetic', nickname: '示例用户');
// Deliberately invalid signature, accepted only by this in-process adapter.
// It prevents the real HTTP preflight from treating a synthetic UID as an
// expired session. It cannot authenticate against any server.
final _fixtureToken =
    '${base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '')}.'
    '${base64Url.encode(utf8.encode(jsonEncode({'sub': _uid, 'exp': 4102444800}))).replaceAll('=', '')}.'
    'c3ludGhldGlj';

class _DenyNetwork extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) =>
      throw StateError('Raw network forbidden in refined pages fixture');
}

class _PickerAdapter implements HttpClientAdapter {
  bool failList = false;
  int listCalls = 0;
  final unexpected = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    if (options.method != 'GET' || path != '/api/v1/organizations/mine') {
      unexpected.add('${options.method} $path');
      throw StateError('Unexpected fixture request: $path');
    }
    expect(options.queryParameters, {'page': 1, 'size': 100});
    expect(options.headers[Keys.tokenKey], _fixtureToken);
    listCalls++;
    return ResponseBody.fromString(
      jsonEncode(
        failList
            ? {'code': 500, 'msg': 'synthetic load failure'}
            : {
                'code': 0,
                'payload': {
                  'list': [
                    {'id': 7001, 'name': '示例产品团队', 'member_role': 'owner'},
                    {
                      'id': 7002,
                      'name': '示例研发协作空间与长名称展示',
                      'member_role': 'member',
                    },
                  ],
                  'page': 1,
                  'size': 100,
                  'total': 2,
                  'total_page': 1,
                },
              },
      ),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Attachments extends PersonalAttachmentRepository {
  bool failLoad = false;
  final keywords = <String>[];

  @override
  Future<List<PersonalAttachment>> page({
    int offset = 0,
    int limit = 40,
    String keyword = '',
  }) async {
    keywords.add(keyword);
    if (failLoad) throw Exception('synthetic attachment failure');
    return [
      for (final (id, name, type) in [
        ('fixture-file', '项目说明与交付清单.pdf', 'file'),
        ('fixture-image', '界面设计参考.png', 'image'),
        ('fixture-voice', '讨论纪要.m4a', 'voice'),
      ])
        if (name.contains(keyword))
          PersonalAttachment(
            MessageModel.fromJson({
              'id': id,
              'auto_id': 1,
              'type': 'C2C',
              'from_id': _uid,
              'to_id': 'synthetic-peer',
              'payload': jsonEncode({'filename': name}),
              'created_at': 1792742400000,
              'conversation_uk3': 'C2C_${_uid}_synthetic-peer',
              'is_author': 1,
              'status': 11,
              'msg_type': type,
            }),
            name,
          ),
    ];
  }
}

class _Experience extends ProductExperienceNotifier {
  @override
  ProductExperience build() => ProductExperience.personal;
}

class _Theme extends ThemeNotifier {
  _Theme(this.dark);
  final bool dark;
  @override
  ThemeState build() => ThemeState(isDarkMode: dark);
}

class _Mode extends ThemeModeNotifier {
  _Mode(this.dark);
  final bool dark;
  @override
  ThemeMode build() => dark ? ThemeMode.dark : ThemeMode.light;
}

class _Profile extends ProfileNotifier {
  _Profile(this.large);
  final bool large;
  @override
  ProfileState build() => ProfileState(
    userModel: _user,
    nickname: '示例用户',
    completeness: 35,
    completenessLevel: '待完善',
    profession: large ? _longValue : '产品与体验设计协作',
    school: large ? _longValue : '',
    region: large ? '示例地区名称较长需要完整换行展示' : '',
  );

  @override
  void refreshUserData() {} // A destination stub never edits the fixture.
}

const _longValue = '产品与体验设计协作以及跨团队项目规划的较长合成资料';

Future<GoRouter> _mount(
  WidgetTester tester,
  String page, {
  required bool dark,
  _Attachments? attachments,
}) async {
  final router = GoRouter(
    initialLocation: '/$page',
    routes: [
      GoRoute(
        path: '/$page',
        builder: (_, _) => switch (page) {
          'setting' => const SettingPage(),
          'profile' => const ProfilePage(),
          'attachments' => PersonalAttachmentsPage(repository: attachments!),
          'picker' => const OrganizationPickerPage(accountKey: _uid),
          _ => throw StateError('Unknown fixture page $page'),
        },
      ),
      for (final path in [
        '/account_security',
        '/language',
        '/dark_model',
        '/font_size',
        kOrganizationPickerPath,
        '/qrcode/user',
        kOrganizationHomePath,
        '/personal_info/set_nickname',
        '/personal_info/privacy_settings',
      ])
        GoRoute(
          path: path,
          builder: (_, _) =>
              Scaffold(body: Center(child: Text('destination:$path'))),
        ),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        productExperienceProvider.overrideWith(_Experience.new),
        themeProvider.overrideWith(() => _Theme(dark)),
        themeModeProvider.overrideWith(() => _Mode(dark)),
        profileProvider.overrideWith(() => _Profile(dark)),
      ],
      child: TranslationProvider(
        child: RepaintBoundary(
          key: _screen,
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
              child: Material(child: child),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!tester.any(target)) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for $target');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final image = await tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_screen))
      .toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final encoded = base64Encode(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('[REFINED_PNG_BEGIN:$name:${encoded.length}]');
    for (var offset = 0; offset < encoded.length; offset += 800) {
      // ignore: avoid_print
      print(
        '[REFINED_PNG:$name:$offset]'
        '${encoded.substring(offset, math.min(offset + 800, encoded.length))}',
      );
    }
    // ignore: avoid_print
    print('[REFINED_PNG_END:$name:${encoded.length}]');
  } finally {
    image.dispose();
  }
}

Future<void> _tapStub(
  WidgetTester tester,
  GoRouter router,
  Finder source,
  String destination,
) async {
  await Scrollable.ensureVisible(tester.element(source), alignment: 0.5);
  await tester.pumpAndSettle();
  expect(source.hitTestable(), findsOneWidget);
  await tester.tap(source.hitTestable());
  await tester.pumpAndSettle();
  expect(find.text('destination:$destination'), findsOneWidget);
  router.pop();
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final adapter = _PickerAdapter();
  final previousHttpOverrides = io.HttpOverrides.current;
  final previousAdapter = app_http.HttpClient.adapterForTest;
  setUpAll(() {
    pinLoopbackTestEnv();
    io.HttpOverrides.global = _DenyNetwork();
    app_http.HttpClient.adapterForTest = adapter;
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'secure_token': _fixtureToken});
    expect(tokenExpired(_fixtureToken), isFalse);
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, _uid);
    await StorageService.setMap(Keys.currentUser, {
      'uid': _uid,
      'account': 'synthetic',
      'nickname': '示例用户',
      'avatar': '',
      'email': '',
      'mobile': '',
    });
    LocaleSettings.setLocale(AppLocale.zhCn);
    AppFeatureRegistry.replaceSnapshotForTest({});
    OrganizationCache.disposeAccount(_uid);
    CurrentOrganizationStore.disposeAccount(_uid);
    adapter.failList = false;
    adapter.listCalls = 0;
    adapter.unexpected.clear();
  });
  tearDown(() {
    expect(adapter.unexpected, isEmpty);
    OrganizationCache.disposeAccount(_uid);
    CurrentOrganizationStore.disposeAccount(_uid);
    AppFeatureRegistry.replaceSnapshotForTest({});
  });
  tearDownAll(() {
    app_http.HttpClient.adapterForTest = previousAdapter;
    io.HttpOverrides.global = previousHttpOverrides;
  });

  for (final dark in [false, true]) {
    final mode = dark ? 'dark_large' : 'light';
    testWidgets('refined setting $mode: layout and destinations', (
      tester,
    ) async {
      final router = await _mount(tester, 'setting', dark: dark);
      expect(find.text(t.account.accountSecurity), findsOneWidget);
      await _capture(tester, 'refined_setting_$mode');
      await _tapStub(
        tester,
        router,
        find.text(t.common.languageSetting),
        '/language',
      );
      await _tapStub(
        tester,
        router,
        find.text(t.organization.experienceUi.switchSpace),
        kOrganizationPickerPath,
      );
      await tester.scrollUntilVisible(find.text(t.account.logoutAccount), 220);
      expect(tester.takeException(), isNull);
      expect(adapter.listCalls, 0);
    });
    testWidgets('refined profile $mode: compact identity and actions', (
      tester,
    ) async {
      final router = await _mount(tester, 'profile', dark: dark);
      expect(
        find.byKey(const ValueKey('profile-identity-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('profile-background-cover')),
        findsNothing,
      );
      expect(find.text('35%'), findsOneWidget);
      await _capture(tester, 'refined_profile_$mode');
      await tester.tap(find.byKey(const ValueKey('profile-avatar-edit')));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
      if (dark) {
        await tester.scrollUntilVisible(find.text(_longValue).first, 220);
        expect(tester.takeException(), isNull);
        await _capture(tester, 'refined_profile_dark_large_details');
      }
      await tester.scrollUntilVisible(find.text(t.account.myQRCode), 220);
      await _tapStub(
        tester,
        router,
        find.text(t.account.myQRCode),
        '/qrcode/user',
      );
      expect(tester.takeException(), isNull);
      expect(adapter.listCalls, 0);
    });
    testWidgets('refined attachments $mode: local index and search', (
      tester,
    ) async {
      final repository = _Attachments();
      await _mount(tester, 'attachments', dark: dark, attachments: repository);
      await _waitFor(tester, find.text('项目说明与交付清单.pdf'));
      expect(
        find.byKey(const ValueKey('personal-attachment-fixture-file')),
        findsOneWidget,
      );
      await _capture(tester, 'refined_attachments_$mode');
      await tester.enterText(find.byType(CupertinoSearchTextField), '不存在');
      await tester.pump(const Duration(milliseconds: 300));
      await _waitFor(tester, find.text(t.attachmentManager.emptySearch));
      await tester.enterText(find.byType(CupertinoSearchTextField), '界面');
      await tester.pump(const Duration(milliseconds: 300));
      await _waitFor(tester, find.text('界面设计参考.png'));
      expect(find.text('项目说明与交付清单.pdf'), findsNothing);
      expect(repository.keywords, contains('界面'));
      expect(tester.takeException(), isNull);
      expect(adapter.listCalls, 0);
    });
    testWidgets('refined picker $mode: context and safe entry navigation', (
      tester,
    ) async {
      final router = await _mount(tester, 'picker', dark: dark);
      await _waitFor(
        tester,
        find.byKey(const ValueKey('org-picker-tile-7001')),
      );
      expect(
        find.byKey(const ValueKey('org-picker-personal-entry')),
        findsOneWidget,
      );
      expect(find.byIcon(CupertinoIcons.check_mark), findsOneWidget);
      await _capture(tester, 'refined_picker_$mode');
      await tester.tap(find.byKey(const ValueKey('org-picker-join-entry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('org-join-code-field')), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      await _tapStub(
        tester,
        router,
        find.byKey(const ValueKey('org-picker-create-entry')),
        kOrganizationHomePath,
      );
      expect(adapter.listCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('refined attachments: error retry recovers local fixture', (
    tester,
  ) async {
    final repository = _Attachments()..failLoad = true;
    await _mount(tester, 'attachments', dark: false, attachments: repository);
    final retry = find.byKey(const ValueKey('personal-attachment-retry'));
    await _waitFor(tester, retry);
    expect(find.text('项目说明与交付清单.pdf'), findsNothing);
    await _capture(tester, 'refined_attachments_error');
    repository.failLoad = false;
    await tester.tap(retry);
    await _waitFor(tester, find.text('项目说明与交付清单.pdf'));
    expect(repository.keywords, hasLength(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('refined picker: list failure retains actions and retries', (
    tester,
  ) async {
    adapter.failList = true;
    await _mount(tester, 'picker', dark: false);
    final retry = find.widgetWithText(TextButton, '重试');
    await _waitFor(tester, retry);
    expect(find.byKey(const ValueKey('org-picker-join-entry')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-picker-create-entry')),
      findsOneWidget,
    );
    await _capture(tester, 'refined_picker_error');
    adapter.failList = false;
    await tester.tap(retry);
    await _waitFor(tester, find.byKey(const ValueKey('org-picker-tile-7001')));
    expect(adapter.listCalls, 2);
    expect(tester.takeException(), isNull);
  });
}
