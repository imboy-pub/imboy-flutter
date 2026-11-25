// SettingPage explicit Web 登出撤销域（拆分自原 setting_page_test.dart，
// ratchet <800 行约束）；共享 fixture 见 setting_page_support.dart。

import 'dart:async';

import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:imboy/component/ui/common_bar.dart' show GlassBackButton;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/detail_settings_tile.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' as init;
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/mine/setting/setting_page.dart';
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

  group('explicit Web logout revocation', () {
    late String previousDid;
    late String previousUid;
    late Map<String, dynamic> previousUser;
    setUp(() {
      previousDid = init.deviceId;
      previousUid = UserRepoLocal.to.currentUid;
      previousUser = StorageService.getMap(Keys.currentUser);
      init.deviceId = 'web_synthetic_logout';
    });
    tearDown(() async {
      init.deviceId = previousDid;
      await StorageService.to.setString(Keys.currentUid, previousUid);
      await StorageService.setMap(Keys.currentUser, previousUser);
      UserRepoLocal.to.notifyListeners();
    });

    Future<void> open(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text(t.account.logOut),
        220,
        scrollable: find
            .descendant(
              of: find.byType(SettingPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text(t.account.logOut));
      await tester.pumpAndSettle();
    }

    Future<void> confirm(WidgetTester tester) async {
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pumpAndSettle();
    }

    testWidgets('cancel sends no request and does not clear local session', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      await pumpSettingPage(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) async {
          guard();
          requests++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(quits, 0);
      await unmountSettingPage(tester);
    });

    testWidgets(
      'success revokes current bound DID before generation-scoped local logout',
      (tester) async {
        final events = <String>[];
        final generation = UserRepoLocal.to.sessionGeneration;
        var completedGeneration = generation;
        int? quitGeneration;
        await pumpSettingPage(
          tester,
          webMode: true,
          isLoggedOutAfter: (original) {
            expect(original, generation);
            return completedGeneration == original + 1 &&
                UserRepoLocal.to.currentUid.isEmpty;
          },
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (did, guard) async {
            guard();
            events.add('delete:$did');
            return true;
          },
          quitLocal: (expected) async {
            quitGeneration = expected;
            events.add('quit');
            await StorageService.to.setString(Keys.currentUid, '');
            completedGeneration++;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(events, ['delete:web_synthetic_logout', 'quit']);
        expect(quitGeneration, generation);
        expect(find.text('signed out stub'), findsOneWidget);
        await unmountSettingPage(tester);
      },
    );

    for (final replaceAccount in [false, true]) {
      testWidgets('shell disposal during cleanup replacement=$replaceAccount', (
        tester,
      ) async {
        final sessions = FakeLogoutSessions();
        final generation = UserRepoLocal.to.sessionGeneration;
        var completedGeneration = generation;
        final cleanup = Completer<bool>();
        await pumpSettingPage(
          tester,
          webMode: true,
          shellSessions: sessions,
          isLoggedOutAfter: (original) {
            expect(original, generation);
            return completedGeneration == original + 1 &&
                UserRepoLocal.to.currentUid.isEmpty;
          },
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (_, guard) async {
            guard();
            return true;
          },
          quitLocal: (_) {
            sessions.transition();
            return cleanup.future;
          },
        );
        await open(tester);
        await tester.tap(find.text(t.common.buttonConfirm));
        await tester.pumpAndSettle();
        expect(find.byType(SettingPage), findsNothing);
        await StorageService.to.setString(
          Keys.currentUid,
          replaceAccount ? 'new_synthetic_owner' : '',
        );
        cleanup.complete(true);
        completedGeneration = generation + (replaceAccount ? 2 : 1);
        await tester.pumpAndSettle();
        expect(
          find.text('signed out stub'),
          replaceAccount ? findsNothing : findsOneWidget,
        );
        if (replaceAccount) {
          expect(UserRepoLocal.to.currentUid, 'new_synthetic_owner');
        }
        await unmountSettingPage(tester);
        sessions.dispose();
      });
    }

    for (final throws in [false, true]) {
      testWidgets(
        'delete ${throws ? 'throw' : 'false'} preserves session and permits retry',
        (tester) async {
          var requests = 0;
          var quits = 0;
          await pumpSettingPage(
            tester,
            webMode: true,
            readWebDeviceId: () async => init.deviceId,
            revokeWebDevice: (_, guard) async {
              guard();
              requests++;
              if (requests == 1) {
                if (throws) throw StateError('synthetic offline');
                return false;
              }
              return true;
            },
            quitLocal: (_) async {
              quits++;
              return true;
            },
          );
          await open(tester);
          await confirm(tester);
          expect(requests, 1);
          expect(quits, 0);
          expect(UserRepoLocal.to.currentUid, previousUid);
          await EasyLoading.dismiss(animation: false);
          await tester.pumpAndSettle();
          await open(tester);
          await confirm(tester);
          expect(requests, 2);
          expect(quits, 1);
          await unmountSettingPage(tester);
        },
      );
    }

    testWidgets('in-flight intent prevents a second revoke or dialog', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      final pending = Completer<bool>();
      await pumpSettingPage(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) {
          guard();
          requests++;
          return pending.future;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await tester.scrollUntilVisible(find.text(t.account.logOut), 220);
      final row = tester.widget<DetailSettingsTile>(
        find
            .ancestor(
              of: find.text(t.account.logOut),
              matching: find.byType(DetailSettingsTile),
            )
            .first,
      );
      row.onTap!();
      row.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      await confirm(tester);
      expect(requests, 1);
      row.onTap!();
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(requests, 1);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(quits, 1);
      await unmountSettingPage(tester);
    });

    testWidgets('late delete cannot clear a replacement account', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      final pending = Completer<bool>();
      await pumpSettingPage(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, guard) {
          guard();
          requests++;
          return pending.future;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await confirm(tester);
      expect(requests, 1);
      await StorageService.to.setString(
        Keys.currentUid,
        'replacement_synthetic_uid',
      );
      UserRepoLocal.to.notifyListeners();
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(quits, 0);
      expect(UserRepoLocal.to.currentUid, 'replacement_synthetic_uid');
      expect(find.text('signed out stub'), findsNothing);
      await unmountSettingPage(tester);
    });

    testWidgets(
      'DID mismatch rejects Web logout without revoke or local cleanup',
      (tester) async {
        var requests = 0;
        var quits = 0;
        await pumpSettingPage(
          tester,
          webMode: true,
          readWebDeviceId: () async => 'different_synthetic_did',
          revokeWebDevice: (_, _) async {
            requests++;
            return true;
          },
          quitLocal: (_) async {
            quits++;
            return true;
          },
        );
        await open(tester);
        expect(find.byType(CupertinoAlertDialog), findsNothing);
        expect(requests, 0);
        expect(quits, 0);
        await unmountSettingPage(tester);
      },
    );

    testWidgets('account replacement during confirmation cancels revocation', (
      tester,
    ) async {
      var requests = 0;
      var quits = 0;
      await pumpSettingPage(
        tester,
        webMode: true,
        readWebDeviceId: () async => init.deviceId,
        revokeWebDevice: (_, _) async {
          requests++;
          return true;
        },
        quitLocal: (_) async {
          quits++;
          return true;
        },
      );
      await open(tester);
      await StorageService.to.setString(
        Keys.currentUid,
        'replacement_during_dialog',
      );
      UserRepoLocal.to.notifyListeners();
      await confirm(tester);
      expect(requests, 0);
      expect(quits, 0);
      expect(UserRepoLocal.to.currentUid, 'replacement_during_dialog');
      await unmountSettingPage(tester);
    });

    testWidgets(
      'server kick before delete response does not clear twice or report delete success',
      (tester) async {
        var requests = 0;
        var quits = 0;
        final pending = Completer<bool>();
        await pumpSettingPage(
          tester,
          webMode: true,
          readWebDeviceId: () async => init.deviceId,
          revokeWebDevice: (_, guard) {
            guard();
            requests++;
            return pending.future;
          },
          quitLocal: (_) async {
            quits++;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(requests, 1);
        // Model automatic cleanup independently of the explicit logout callback.
        await StorageService.to.setString(Keys.currentUid, '');
        UserRepoLocal.to.notifyListeners();
        pending.complete(false);
        await tester.pumpAndSettle();
        expect(quits, 0);
        expect(find.text(t.common.logoutFailed), findsNothing);
        expect(find.text('signed out stub'), findsNothing);
        await unmountSettingPage(tester);
      },
    );

    testWidgets(
      'Native explicit logout adds no device lookup or revoke request',
      (tester) async {
        var deviceReads = 0;
        var requests = 0;
        int? generation;
        await pumpSettingPage(
          tester,
          readWebDeviceId: () async {
            deviceReads++;
            return init.deviceId;
          },
          revokeWebDevice: (_, _) async {
            requests++;
            return true;
          },
          quitLocal: (expected) async {
            generation = expected;
            return true;
          },
        );
        await open(tester);
        await confirm(tester);
        expect(deviceReads, 0);
        expect(requests, 0);
        expect(generation, isNull);
        expect(find.text('native signed out stub'), findsOneWidget);
        await unmountSettingPage(tester);
      },
    );
  });

  testWidgets(
    'Web reuses appearance settings but exposes privacy as static data',
    (tester) async {
      await pumpSettingPage(tester, webMode: true);
      expect(find.text(t.common.languageSetting), findsOneWidget);
      expect(find.text(t.main.darkModel), findsOneWidget);
      expect(find.text(t.common.fontSettings), findsOneWidget);
      final privacy = tester.widget<DetailSettingsTile>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DetailSettingsTile &&
              widget.title is Text &&
              (widget.title as Text).data == t.common.allowSearchMe,
        ),
      );
      expect(privacy.onTap, isNull);
      expect(privacy.trailing, isNull);
      expect(privacy.value, t.common.unknown);
      expect(find.byType(CupertinoSwitch), findsNothing);
      expect(find.text(t.account.accountSecurity), findsNothing);
      await tester.scrollUntilVisible(find.text(t.account.logOut), 220);
      expect(find.text(t.common.switchEnvironment), findsNothing);
      expect(find.text(t.account.logoutAccount), findsNothing);
      await unmountSettingPage(tester);
    },
  );

  test('account privacy overrides stale global settings and follows account changes', () async {
    final previousUser = StorageService.getMap(Keys.currentUser);
    final previousSetting = StorageService.to.getString('setting');
    final container = ProviderContainer();
    await StorageService.to.setString('setting', '{"allow_search":true}');
    await StorageService.setMap(Keys.currentUser, {
      ...previousUser,
      'setting': {'allow_search': 2},
    });
    final subscription = container.listen(allowSearchProvider, (_, _) {});
    try {
      expect(container.read(allowSearchProvider), isFalse);
      await StorageService.setMap(Keys.currentUser, {
        ...previousUser,
        'uid': 'synthetic-other-settings-owner',
        'setting': {'allow_search': 1},
      });
      UserRepoLocal.to.notifyListeners();
      expect(container.read(allowSearchProvider), isTrue);
    } finally {
      subscription.close();
      container.dispose();
      await StorageService.setMap(Keys.currentUser, previousUser);
      if (previousSetting.isEmpty) {
        await StorageService.to.remove('setting');
      } else {
        await StorageService.to.setString('setting', previousSetting);
      }
      UserRepoLocal.to.notifyListeners();
    }
  });

  testWidgets('设置图标保持中性，无彩色实心底', (tester) async {
    await pumpSettingPage(tester);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.lock_shield)).color,
      AppColors.getTextColor(Brightness.light, isSecondary: true),
    );
    await unmountSettingPage(tester);
  });
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('设置 $width × $scale $brightness 字体导航返回且末尾可达', (
          tester,
        ) async {
          await pumpSettingPage(
            tester,
            width: width,
            scale: scale,
            brightness: brightness,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final fontSetting = find.text(t.common.fontSettings);
          await tester.ensureVisible(fontSetting);
          expect(fontSetting.hitTestable(), findsOneWidget);
          await tester.tap(find.text(t.common.fontSettings));
          await tester.pumpAndSettle();
          expect(find.byType(FontSizePage), findsOneWidget);
          expect(find.byType(Slider), findsOneWidget);
          expect(find.text(t.main.thisIsTitleText), findsOneWidget);
          final context = tester.element(find.byType(FontSizePage));
          expect(GoRouterState.of(context).uri.path, '/font_size');
          await tester.tap(find.byType(GlassBackButton));
          await tester.pumpAndSettle();
          expect(find.byType(FontSizePage), findsNothing);
          expect(find.byType(SettingPage), findsOneWidget);
          expect(
            find.text(t.common.fontSettings).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text(t.account.logoutAccount),
            220,
          );
          await tester.pumpAndSettle();
          expect(
            find.text(t.account.logoutAccount).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await unmountSettingPage(tester);
        });
      }
    }
  }
}
