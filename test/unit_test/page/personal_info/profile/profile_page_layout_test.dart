import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/profile/profile_page.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';

class _Fixture extends ProfileNotifier {
  _Fixture(this.fixture);
  final ProfileState fixture;
  @override
  ProfileState build() => fixture;
}

const _longValue = '很长的资料值需要完整换行显示🙂abcdefghijklmnopqrstuv';
ProfileState _state({bool long = false, bool background = false}) =>
    ProfileState(
      userModel: UserModel(uid: 'profile-test', account: 'synthetic-account'),
      nickname: long ? _longValue : '示例用户',
      email: long ? _longValue : '未设置',
      mobile: long ? _longValue : '未设置',
      region: long ? _longValue : '',
      signature: long ? _longValue : '',
      profession: long ? _longValue : '',
      school: long ? _longValue : '',
      interests: long ? _longValue : '',
      background: background ? 'def_avatar.png' : '',
      completeness: 67,
      completenessLevel: '良好',
    );

Future<void> _mount(
  WidgetTester tester, {
  double width = 390,
  double scale = 1,
  Brightness brightness = Brightness.light,
  bool long = false,
  bool background = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await StorageService.setMap(Keys.currentUser, {
    'uid': 'profile-test',
    'account': 'synthetic-account',
    'nickname': '示例用户',
  });
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
      GoRoute(
        path: '/personal_info/set_nickname',
        builder: (_, _) => const Scaffold(body: Text('nickname destination')),
      ),
      GoRoute(
        path: '/qrcode/user',
        builder: (_, _) => const Scaffold(body: Text('QR destination')),
      ),
      GoRoute(
        path: '/personal_info/privacy_settings',
        builder: (_, _) => const Scaffold(body: Text('privacy destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          () => _Fixture(_state(long: long, background: background)),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(brightness: brightness),
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

void main() {
  tearDown(() async {
    await StorageService.to.remove(Keys.currentUser);
  });
  testWidgets('联系方式仅展示，不暴露编辑入口', (tester) async {
    await _mount(tester);
    for (final label in [t.account.email, t.account.mobile]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      final tile = tester.widget<DetailSettingsTile>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(DetailSettingsTile),
        ),
      );
      expect(tile.onTap, isNull);
      expect(tile.trailing, isNull);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsNothing);
    }
  });
  testWidgets('资料头紧凑无装饰渐变，完整度百分比只展示一次', (tester) async {
    await _mount(tester);
    expect(find.text('67%'), findsOneWidget);
    expect(find.bySemanticsLabel(t.common.avatarEditAvatar), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).gradient != null,
      ),
      findsNothing,
    );
    expect(find.text('示例用户'), findsNWidgets(2));
  });
  testWidgets('真实自定义背景仍展示，编辑头像为独立入口', (tester) async {
    await _mount(tester, background: true);
    expect(
      find.byKey(const ValueKey('profile-background-cover')),
      findsOneWidget,
    );
    await tester.tap(find.bySemanticsLabel(t.common.avatarEditAvatar));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(find.text(t.main.takePhoto), findsOneWidget);
    expect(find.text(t.main.selectFromAlbum), findsOneWidget);
  });
  testWidgets('完整度摘要可访问后续建议并保留生日编辑', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(const ValueKey('profile-completion')));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.setAvatar), findsOneWidget);
    expect(find.text(t.account.setGender), findsOneWidget);
    expect(find.text(t.common.setRegion), findsOneWidget);
    expect(find.text(t.chat.setSignature), findsOneWidget);
    await tester.tap(find.text(t.account.setBirthday));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
  });

  testWidgets('昵称编辑路由保持不变', (tester) async {
    await _mount(tester);
    await tester.ensureVisible(find.text(t.account.nickname));
    await tester.tap(find.text(t.account.nickname));
    await tester.pumpAndSettle();
    expect(find.text('nickname destination'), findsOneWidget);
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0]) {
      testWidgets('资料长字段 $width $brightness 双倍字号无溢出', (tester) async {
        await _mount(
          tester,
          width: width,
          brightness: brightness,
          scale: 2,
          long: true,
        );
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.text(t.common.privacySettings),
          240,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
