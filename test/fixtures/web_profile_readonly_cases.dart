import 'dart:ui' as ui;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/page/personal_info/profile/profile_page.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/personal_info/personal_info_page.dart';
import 'package:imboy/page/personal_info/widget/more_page.dart';
import 'package:imboy/page/qrcode/user_qrcode_page.dart';
import 'package:imboy/page/qrcode/qrcode_url.dart';
import 'package:imboy/page/web_shell/web_shell_helper_panels.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'web_profile_io_fence.dart';

class _FixtureUser extends Notifier<UserModel?> {
  @override
  UserModel? build() => null;
  void publish(UserModel? user) => state = user;
}

final _fixtureUser = NotifierProvider<_FixtureUser, UserModel?>(
  _FixtureUser.new,
);

class _NoProductEnv implements Env {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:0';
  @override
  String get wsUrl => 'ws://127.0.0.1:0/ws';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(prepareWebWriter);
  late ProviderContainer container;
  late GoRouter router;
  late ProfileIoFence fence;
  late String previousEnv;
  late Map<String, Env> previousEnvs;
  UserModel user({
    String uid = '990001',
    String nickname = '合成用户',
    String account = 'synthetic-account',
    String email = 'synthetic@example.invalid',
    int gender = 3,
    String region = '合成地区',
    String sign = '合成签名',
  }) => UserModel(
    uid: uid,
    account: account,
    nickname: nickname,
    email: email,
    avatar: '',
    gender: gender,
    region: region,
    sign: sign,
  );
  Future<void> publish(UserModel? user) async {
    // Only test-isolate in-memory preferences; no login/logout/secret/DB methods.
    await StorageService.to.setString(Keys.currentUid, user?.uid ?? '');
    await StorageService.setMap(Keys.currentUser, user?.toMap() ?? {});
    container.read(_fixtureUser.notifier).publish(user);
  }

  setUp(() async {
    previousEnv = init.currentEnv;
    previousEnvs = Map.of(envMap);
    init.currentEnv = 'profile-owned';
    envMap['profile-owned'] = _NoProductEnv();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    fence = ProfileIoFence()..install();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWith((ref) => ref.watch(_fixtureUser)),
      ],
    );
    router = GoRouter(
      initialLocation: '/mine',
      routes: [
        GoRoute(
          path: '/mine',
          builder: (_, _) =>
              const WebMineMinPanel(section: null, logoutLabel: 'logout'),
        ),
        GoRoute(
          path: '/personal_info/profile',
          builder: (_, _) => const ProfilePage(),
        ),
        GoRoute(path: '/qrcode/user', builder: (_, _) => UserQrCodePage()),
      ],
    );
  });
  tearDown(() {
    router.dispose();
    container.dispose();
    try {
      fence.verifyAndRestore();
    } finally {
      envMap
        ..clear()
        ..addAll(previousEnvs);
      init.currentEnv = previousEnv;
    }
  });
  Future<void> mount(
    WidgetTester tester,
    UserModel? current, {
    double width = 1200,
    double scale = 1,
  }) async {
    await publish(current);
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder tile(String title) => find.byWidgetPredicate(
    (w) =>
        w is DetailSettingsTile &&
        w.title is Text &&
        (w.title as Text).data == title,
  );
  Future<void> open(WidgetTester tester, String title) async {
    final target = find.text(title).last;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> retire(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> expectQrIdentity(WidgetTester tester, String uid) async {
    final viewFinder = find.byKey(const ValueKey('user-qrcode-image'));
    expect(viewFinder, findsOneWidget);
    final view = tester.widget<QrImageView>(viewFinder);
    final paintFinder = find.descendant(
      of: viewFinder,
      matching: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is QrPainter,
      ),
    );
    expect(paintFinder, findsOneWidget);
    final actual =
        tester.widget<CustomPaint>(paintFinder).painter! as QrPainter;
    final expected = QrPainter(
      data: buildUserQrcodeUrl(uid),
      version: view.version,
      errorCorrectionLevel: view.errorCorrectionLevel,
      gapless: view.gapless,
      eyeStyle: view.eyeStyle,
      dataModuleStyle: view.dataModuleStyle,
    );
    // Compare the actual destination's encoded painter, not a fake destination
    // or inaccessible QrImageView._data. The page overlays its logo separately.
    await tester.runAsync(() async {
      final actualPicture = actual.toPicture(256);
      final expectedPicture = expected.toPicture(256);
      final actualImage = await actualPicture.toImage(256, 256);
      final expectedImage = await expectedPicture.toImage(256, 256);
      try {
        final actualBytes = await actualImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final expectedBytes = await expectedImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(actualBytes, isNotNull);
        expect(expectedBytes, isNotNull);
        expect(
          actualBytes!.buffer.asUint8List(
            actualBytes.offsetInBytes,
            actualBytes.lengthInBytes,
          ),
          orderedEquals(
            expectedBytes!.buffer.asUint8List(
              expectedBytes.offsetInBytes,
              expectedBytes.lengthInBytes,
            ),
          ),
          reason: 'Rendered QR must encode the current synthetic user identity',
        );
      } finally {
        actualImage.dispose();
        expectedImage.dispose();
        actualPicture.dispose();
        expectedPicture.dispose();
      }
    });
  }

  void readonlyFields(WidgetTester tester) {
    for (final row in tester.widgetList<DetailSettingsTile>(
      find.byType(DetailSettingsTile),
    )) {
      expect(row.onTap, isNull);
    }
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(CupertinoTextField), findsNothing);
    expect(find.byIcon(CupertinoIcons.camera_fill), findsNothing);
  }

  for (final width in [390.0, 1400.0]) {
    testWidgets(
      'standalone actual ProfilePage readonly body is centered/bounded $width',
      (tester) async {
        final current = user();
        await mount(tester, current, width: width);
        router.go('/personal_info/profile');
        await tester.pumpAndSettle();
        expect(find.byType(ProfilePage), findsOneWidget);
        expect(
          tester.widget<ProfilePage>(find.byType(ProfilePage)).readOnly,
          isTrue,
        );
        expect(find.byType(PersonalInfoPage), findsOneWidget);
        final body = tester.getRect(
          find.descendant(
            of: find.byType(PersonalInfoPage),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(
          body.width,
          closeTo(width.clamp(0, ResourcePageLayout.maxWidth), 1),
        );
        expect(body.center.dx, closeTo(width / 2, 1));
        expect(find.text(current.nickname), findsWidgets);
        expect(find.text(current.account), findsOneWidget);
        expect(
          tester.widget<DetailSettingsTile>(tile(t.account.nickname)).onTap,
          isNull,
        );
        expect(find.byIcon(CupertinoIcons.camera_fill), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'SET01 normal fields, actual read-only More and QR destinations',
    (tester) async {
      final current = user();
      await mount(tester, current);
      expect(
        tester.widget<PersonalInfoPage>(find.byType(PersonalInfoPage)).readOnly,
        isTrue,
      );
      expect(find.text(current.nickname), findsWidgets);
      expect(find.text(current.email), findsOneWidget);
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.account)).value,
        current.account,
      );
      readonlyFields(tester);
      for (final title in [
        t.account.nickname,
        t.account.account,
        t.account.loginEmail,
      ]) {
        await tester.ensureVisible(tile(title));
        await tester.tap(tile(title), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(PersonalInfoPage), findsOneWidget);
        readonlyFields(tester);
      }
      await open(tester, t.common.moreInfo);
      expect(tester.widget<MorePage>(find.byType(MorePage)).readOnly, isTrue);
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.gender)).value,
        t.main.keepSecret,
      );
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.region)).value,
        current.region,
      );
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.signature)).value,
        current.sign,
      );
      for (final title in [
        t.account.gender,
        t.account.region,
        t.account.signature,
      ]) {
        await tester.ensureVisible(tile(title));
        await tester.tap(tile(title), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(MorePage), findsOneWidget);
        readonlyFields(tester);
      }
      router.pop();
      await tester.pumpAndSettle();
      await open(tester, t.account.myQrcode);
      expect(find.byType(UserQrCodePage), findsOneWidget);
      await expectQrIdentity(tester, current.uid);
      expect(find.text(current.nickname), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lock_shield), findsOneWidget);
      // Save/share/scanner are separate capabilities; this case does not invoke them.
      await retire(tester);
    },
  );
  testWidgets('SET01 empty values hide email and use defined fallback', (
    tester,
  ) async {
    await mount(
      tester,
      user(
        nickname: '',
        account: '',
        email: '',
        region: '',
        sign: '',
        gender: 0,
      ),
    );
    expect(find.text(t.account.loginEmail), findsNothing);
    expect(
      tester.widget<DetailSettingsTile>(tile(t.account.nickname)).value,
      t.common.notSet,
    );
    readonlyFields(tester);
    await open(tester, t.common.moreInfo);
    expect(
      tester.widget<DetailSettingsTile>(tile(t.account.gender)).value,
      t.common.unknown,
    );
    expect(
      tester.widget<DetailSettingsTile>(tile(t.account.region)).value,
      t.common.notFilled,
    );
    expect(
      tester.widget<DetailSettingsTile>(tile(t.account.signature)).value,
      t.common.notFilled,
    );
    await retire(tester);
  });
  for (final width in [320.0, 1200.0]) {
    testWidgets(
      'SET01 long text $width at scale2 retains exact fields without overflow',
      (tester) async {
        final long = List.filled(12, '合成中文Long🙂').join();
        await mount(
          tester,
          user(
            nickname: long,
            account: long,
            email: '$long@example.invalid',
            region: long,
            sign: long,
          ),
          width: width,
          scale: 2,
        );
        expect(
          tester.widget<DetailSettingsTile>(tile(t.account.nickname)).value,
          long,
        );
        expect(
          tester.widget<DetailSettingsTile>(tile(t.account.account)).value,
          long,
        );
        expect(tester.takeException(), isNull);
        await open(tester, t.common.moreInfo);
        expect(
          tester.widget<DetailSettingsTile>(tile(t.account.signature)).value,
          long,
        );
        expect(tester.takeException(), isNull);
        await retire(tester);
      },
    );
  }
  testWidgets('SET01 anonymous panel has no profile or destinations', (
    tester,
  ) async {
    await mount(tester, null);
    expect(find.text(t.common.notLoggedIn), findsOneWidget);
    expect(find.byType(PersonalInfoPage), findsNothing);
    expect(find.byType(UserQrCodePage), findsNothing);
    await retire(tester);
  });
  testWidgets(
    'SET01 main and More follow user replacement and anonymous state',
    (tester) async {
      final a = user();
      final b = user(
        uid: '990002',
        nickname: '合成用户B',
        account: 'synthetic-b',
        region: '合成地区B',
        sign: '合成签名B',
      );
      await mount(tester, a);
      await publish(b);
      await tester.pumpAndSettle();
      expect(find.text(a.nickname), findsNothing);
      expect(find.text(b.nickname), findsWidgets);
      await publish(a);
      await tester.pumpAndSettle();
      await open(tester, t.common.moreInfo);
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.region)).value,
        a.region,
      );
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.signature)).value,
        a.sign,
      );
      await publish(b);
      await tester.pumpAndSettle();
      expect(find.byType(MorePage), findsOneWidget);
      expect(find.text(a.region), findsNothing);
      expect(find.text(a.sign), findsNothing);
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.region)).value,
        b.region,
      );
      expect(
        tester.widget<DetailSettingsTile>(tile(t.account.signature)).value,
        b.sign,
      );
      readonlyFields(tester);
      await publish(null);
      await tester.pumpAndSettle();
      expect(find.text(b.region), findsNothing);
      expect(find.text(b.sign), findsNothing);
      expect(find.text(b.nickname), findsNothing);
      expect(find.text(t.common.notLoggedIn), findsWidgets);
      await retire(tester);
    },
  );
  // Page-level response contract only: this minimal router does not establish root auth-redirection behavior.
  testWidgets(
    'SET01 existing QR destination must replace old identity without remount',
    (tester) async {
      final a = user();
      final b = user(uid: '990002', nickname: '合成用户B');
      await mount(tester, a);
      await open(tester, t.account.myQrcode);
      await publish(b);
      await tester.pumpAndSettle();
      expect(find.text(a.nickname), findsNothing);
      await expectQrIdentity(tester, b.uid);
      await retire(tester);
    },
  );
  testWidgets(
    'SET01 existing QR destination must clear identity when model becomes anonymous',
    (tester) async {
      final a = user();
      await mount(tester, a);
      await open(tester, t.account.myQrcode);
      await publish(null);
      await tester.pumpAndSettle();
      expect(find.text(a.nickname), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text(t.common.notLoggedIn), findsWidgets);
      await retire(tester);
    },
  );
}
