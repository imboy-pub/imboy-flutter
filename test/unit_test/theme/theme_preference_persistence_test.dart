import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show currentFontSize;
import 'package:imboy/page/mine/dark_model/dark_model_page.dart';
import 'package:imboy/page/mine/font_size/font_size_page.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/chat/widget/chat_background_manager.dart';
import 'package:imboy/theme/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _Preferences extends InMemorySharedPreferencesStore {
  _Preferences(super.data) : super.withData();
  String? rejectKey;
  var throwing = false;
  String? delayKey;
  var delayRead = false;
  var rejectReads = 0;
  final entered = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Map<String, Object>> getAll() async {
    if (rejectReads > 0) {
      rejectReads--;
      throw StateError('synthetic initial read failure');
    }
    if (delayRead && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.getAll();
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == delayKey && !entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    if (key == rejectKey) {
      rejectKey = null; // Compensation can restore the previous durable value.
      if (throwing) throw StateError('synthetic preference failure');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late SharedPreferences prefs;
  final subscriptions = <ProviderSubscription<dynamic>>[];

  Map<String, Object> initial() => {
    'theme_is_dark_mode': false,
    'theme_follow_system': false,
    'theme_font_size': 'normal',
    'theme_use_dynamic_color': false,
    Keys.currentUid: '1001',
    Keys.currentUser: jsonEncode({
      'uid': '1001',
      'setting': {'font_size': 'normal'},
    }),
  };

  Future<ThemeNotifier> ready() async {
    subscriptions.add(container.listen(themeProvider, (_, _) {}));
    subscriptions.add(container.listen(themeModeProvider, (_, _) {}));
    final notifier = container.read(themeProvider.notifier);
    await notifier.loadThemePreference();
    return notifier;
  }

  Future<_Preferences> store() async {
    final value = _Preferences(
      await SharedPreferencesStorePlatform.instance.getAll(),
    );
    SharedPreferencesStorePlatform.instance = value;
    return value;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(initial());
    await StorageService.init();
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer();
  });

  tearDown(() {
    for (final subscription in subscriptions) {
      subscription.close();
    }
    subscriptions.clear();
    container.dispose();
    binding.platformDispatcher.clearPlatformBrightnessTestValue();
  });

  for (final followSystem in [true, false]) {
    for (final savedDark in [true, false]) {
      test('effective colors follow=$followSystem savedDark=$savedDark', () async {
        SharedPreferences.setMockInitialValues({
          ...initial(),
          'theme_follow_system': followSystem,
          'theme_is_dark_mode': savedDark,
        });
        await StorageService.init();
        prefs = await SharedPreferences.getInstance();
        final theme = await ready();
        final stateBefore = container.read(themeProvider);
        final persistedBefore = {
          for (final key in prefs.getKeys()) key: prefs.get(key),
        };
        // The same live getter must respond to both system values, without
        // changing saved mode or needing a preference write/reinitialization.
        for (final system in [Brightness.dark, Brightness.light]) {
          binding.platformDispatcher.platformBrightnessTestValue = system;
          final dark = followSystem ? system == Brightness.dark : savedDark;
          expect(
            theme.getThemeColor('primary'),
            dark ? AppColors.primaryLight : AppColors.primary,
          );
          final surface = dark
              ? AppColors.getDarkSurface(false, Brightness.dark)
              : AppColors.lightSurface;
          expect(theme.getThemeColor('surface'), surface);
          expect(
            theme.getThemeColor('background'),
            dark
                ? AppColors.getDarkBackground(false, Brightness.dark)
                : AppColors.lightBackground,
          );
          expect(
            theme.getThemeColor('textPrimary'),
            dark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          );
          expect(
            theme.getThemeColor('textSecondary'),
            dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          );
          expect(
            theme.getThemeColor('border'),
            dark ? AppColors.darkBorder : AppColors.lightBorder,
          );
          expect(
            theme.getThemeColor('error'),
            dark ? AppColors.darkError : AppColors.lightError,
          );
          expect(
            theme.getThemeColor('onSurface'),
            theme.getThemeColor('textPrimary'),
          );
          // Actual default chat background consumer, no image decode or UI IO.
          expect(
            container
                .read(chatBackgroundManagerProvider.notifier)
                .getCurrentBackgroundDecoration()
                .color,
            surface,
          );
          expect(container.read(themeProvider), same(stateBefore));
          expect({
            for (final key in prefs.getKeys()) key: prefs.get(key),
          }, equals(persistedBefore));
        }
      });
    }
  }

  for (final throwing in [false, true]) {
    test(
      'failed font save never publishes or survives restart (throw=$throwing)',
      () async {
        final theme = await ready();
        final fake = await store();
        fake.rejectKey = 'flutter.theme_font_size';
        fake.throwing = throwing;
        await expectLater(
          theme.updateFontSizeOption(FontSizeOption.huge),
          throwsStateError,
        );
        expect(
          container.read(themeProvider).fontSizeOption,
          FontSizeOption.normal,
        );
        expect(
          theme.cachedLightTheme.textTheme.bodyMedium!.fontSize,
          theme.lightTheme.textTheme.bodyMedium!.fontSize,
        );
        await prefs.reload();
        expect(prefs.getString('theme_font_size'), 'normal');
        final restored = ProviderContainer();
        final keep = restored.listen(themeProvider, (_, _) {});
        try {
          await restored.read(themeProvider.notifier).loadThemePreference();
          expect(
            restored.read(themeProvider).fontSizeOption,
            FontSizeOption.normal,
          );
        } finally {
          keep.close();
          restored.dispose();
        }
      },
    );
  }

  test(
    'partial dark/system write is compensated and no provider disagrees',
    () async {
      await ready();
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      final fake = await store();
      fake.rejectKey = 'flutter.theme_follow_system';
      await expectLater(
        container
            .read(themeModeProvider.notifier)
            .setThemeMode(ThemeMode.system),
        throwsStateError,
      );
      expect(container.read(themeModeProvider), ThemeMode.light);
      expect(container.read(themeProvider).isDarkMode, isFalse);
      await prefs.reload();
      expect(prefs.getBool('theme_is_dark_mode'), isFalse);
      expect(prefs.getBool('theme_follow_system'), isFalse);
    },
  );

  test(
    'late startup read cannot replace an explicit mode or font selection',
    () async {
      SharedPreferences.setMockInitialValues(initial());
      final fake = _Preferences(
        await SharedPreferencesStorePlatform.instance.getAll(),
      )..delayRead = true;
      SharedPreferencesStorePlatform.instance = fake;
      subscriptions.add(container.listen(themeModeProvider, (_, _) {}));
      final theme = container.read(themeProvider.notifier);
      await fake.entered.future.timeout(const Duration(seconds: 2));
      final mode = container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      final font = theme.updateFontSizeOption(FontSizeOption.huge);
      fake.release.complete();
      await Future.wait([mode, font]);
      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(container.read(themeProvider).fontSizeOption, FontSizeOption.huge);
      final loaded = await SharedPreferences.getInstance();
      expect(loaded.getBool('theme_is_dark_mode'), isTrue);
      expect(loaded.getString('theme_font_size'), 'huge');
    },
  );

  test(
    'a failed older request cannot roll back a newer successful choice',
    () async {
      final theme = await ready();
      final fake = await store();
      fake.delayKey = fake.rejectKey = 'flutter.theme_font_size';
      final old = theme.updateFontSizeOption(FontSizeOption.large);
      final failed = expectLater(old, throwsStateError);
      await fake.entered.future.timeout(const Duration(seconds: 2));
      final latest = theme.updateFontSizeOption(FontSizeOption.huge);
      fake.release.complete();
      await failed;
      await latest;
      expect(container.read(themeProvider).fontSizeOption, FontSizeOption.huge);
      expect(prefs.getString('theme_font_size'), 'huge');
    },
  );

  test('a user action retries failed startup loading before saving', () async {
    SharedPreferences.setMockInitialValues({
      ...initial(),
      'theme_is_dark_mode': true,
    });
    final fake = _Preferences(
      await SharedPreferencesStorePlatform.instance.getAll(),
    )..rejectReads = 1;
    SharedPreferencesStorePlatform.instance = fake;
    subscriptions.add(container.listen(themeProvider, (_, _) {}));
    final theme = container.read(themeProvider.notifier);
    await theme.updateFontSizeOption(FontSizeOption.huge);
    expect(container.read(themeProvider).isDarkMode, isTrue);
    expect(container.read(themeProvider).fontSizeOption, FontSizeOption.huge);
    final loaded = await SharedPreferences.getInstance();
    expect(loaded.getBool('theme_is_dark_mode'), isTrue);
    expect(loaded.getString('theme_font_size'), 'huge');
  });

  test('real dark-mode caller retains its selection on save failure', () async {
    await ready();
    subscriptions.add(container.listen(darkModelProvider, (_, _) {}));
    final fake = await store();
    fake.rejectKey = 'flutter.theme_is_dark_mode';
    await expectLater(
      container.read(darkModelProvider.notifier).tapDarkItem(3),
      throwsStateError,
    );
    expect(container.read(themeModeProvider), ThemeMode.light);
    expect(container.read(darkModelProvider).selectIndex, 2);
    expect(prefs.getBool('theme_is_dark_mode'), isFalse);
  });

  test(
    'real dark-mode caller follows the system durably without a second writer',
    () async {
      await ready();
      binding.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      subscriptions.add(container.listen(darkModelProvider, (_, _) {}));
      await container
          .read(darkModelProvider.notifier)
          .configSwitchOnChanged(true);
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(themeProvider).followSystemTheme, isTrue);
      expect(container.read(darkModelProvider).switchValue, isTrue);
      expect(prefs.getBool('theme_follow_system'), isTrue);
      await container.read(themeProvider.notifier).loadThemePreference();
      expect(container.read(themeModeProvider), ThemeMode.system);
    },
  );

  test(
    'account font rejection compensates the device font before publishing',
    () async {
      final theme = await ready();
      await expectLater(
        theme.updateFontSizeOption(
          FontSizeOption.huge,
          saveAccountFont: () async => false,
        ),
        throwsStateError,
      );
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.normal,
      );
      expect(prefs.getString('theme_font_size'), 'normal');
    },
  );

  test(
    'real font caller does not update the next account after a delayed save',
    () async {
      await ready();
      subscriptions.add(container.listen(fontSizeProvider, (_, _) {}));
      final fake = await store();
      fake.delayKey = 'flutter.theme_font_size';
      final previousFont = currentFontSize.value;
      final saving = container
          .read(fontSizeProvider.notifier)
          .applyFontSize(
            FontSizeOption.values.indexOf(FontSizeOption.huge).toDouble(),
          );
      final failed = expectLater(saving, throwsStateError);
      await fake.entered.future.timeout(const Duration(seconds: 2));
      await StorageService.to.setString(Keys.currentUid, '1002');
      await StorageService.setMap(Keys.currentUser, {
        'uid': '1002',
        'setting': {'font_size': 'small'},
      });
      UserRepoLocal.to.notifyListeners();
      fake.release.complete();
      await failed;
      expect(UserRepoLocal.to.currentUid, '1002');
      expect(UserRepoLocal.to.setting.fontSize, 'small');
      expect(currentFontSize.value, previousFont);
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.normal,
      );
    },
  );

  test(
    'account setting write failure reverts the real font caller preview',
    () async {
      await ready();
      subscriptions.add(container.listen(fontSizeProvider, (_, _) {}));
      final fake = await store();
      fake.rejectKey = 'flutter.${Keys.currentUser}';
      await expectLater(
        container
            .read(fontSizeProvider.notifier)
            .applyFontSize(
              FontSizeOption.values.indexOf(FontSizeOption.huge).toDouble(),
            ),
        throwsStateError,
      );
      expect(
        container.read(fontSizeProvider).currentOption,
        FontSizeOption.normal,
      );
      expect(
        container.read(fontSizeProvider).previewOption,
        FontSizeOption.normal,
      );
      expect(UserRepoLocal.to.setting.fontSize, 'normal');
      expect(prefs.getString('theme_font_size'), 'normal');
    },
  );

  test(
    'font save preserves unrelated settings changed during its wait',
    () async {
      await ready();
      subscriptions.add(container.listen(fontSizeProvider, (_, _) {}));
      final fake = await store();
      fake.delayKey = 'flutter.theme_font_size';
      final saving = container
          .read(fontSizeProvider.notifier)
          .applyFontSize(
            FontSizeOption.values.indexOf(FontSizeOption.huge).toDouble(),
          );
      await fake.entered.future.timeout(const Duration(seconds: 2));
      final changed = UserRepoLocal.to.setting..allowAddByQR = false;
      expect(await UserRepoLocal.to.changeSetting(changed), isTrue);
      fake.release.complete();
      await saving;
      expect(UserRepoLocal.to.setting.allowAddByQR, isFalse);
      expect(UserRepoLocal.to.setting.fontSize, 'huge');
      expect(container.read(themeProvider).fontSizeOption, FontSizeOption.huge);
    },
  );

  test(
    'startup restoration yields to a user request and performs no save',
    () async {
      final theme = await ready();
      final saving = theme.updateFontSizeOption(FontSizeOption.huge);
      final restoring = theme.restoreAccountFontSize(
        'small',
        isCurrent: () => true,
      );
      await Future.wait([saving, restoring]);
      expect(container.read(themeProvider).fontSizeOption, FontSizeOption.huge);
      expect(prefs.getString('theme_font_size'), 'huge');
    },
  );

  test(
    'startup account restoration is guarded and does not rewrite preferences',
    () async {
      final theme = await ready();
      await theme.restoreAccountFontSize('small', isCurrent: () => false);
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.normal,
      );
      await theme.restoreAccountFontSize('large', isCurrent: () => true);
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.large,
      );
      expect(prefs.getString('theme_font_size'), 'normal');
    },
  );

  test('disposing during the initial read ignores its late result', () async {
    SharedPreferences.setMockInitialValues(initial());
    final fake = _Preferences(
      await SharedPreferencesStorePlatform.instance.getAll(),
    )..delayRead = true;
    SharedPreferencesStorePlatform.instance = fake;
    final local = ProviderContainer();
    local.listen(themeProvider, (_, _) {});
    await fake.entered.future.timeout(const Duration(seconds: 2));
    local.dispose();
    fake.release.complete();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    // Any late write raises an uncaught provider error and fails this test.
  });

  test(
    'new account can restore after the previous account selected a font',
    () async {
      final theme = await ready();
      await theme.updateFontSizeOption(FontSizeOption.huge);
      final baseline = theme.fontRequestRevision;
      await theme.restoreAccountFontSize(
        'small',
        expectedRevision: baseline,
        isCurrent: () => true,
      );
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.small,
      );
      expect(
        prefs.getString('theme_font_size'),
        'huge',
        reason: 'restoration does not rewrite the browser fallback',
      );
    },
  );

  test(
    'current account manual selection wins over a late rebased restore',
    () async {
      final theme = await ready();
      await theme.updateFontSizeOption(FontSizeOption.huge);
      final baseline = theme.fontRequestRevision;
      final choosing = theme.updateFontSizeOption(FontSizeOption.large);
      final restoring = theme.restoreAccountFontSize(
        'small',
        expectedRevision: baseline,
        isCurrent: () => true,
      );
      await Future.wait([choosing, restoring]);
      expect(
        container.read(themeProvider).fontSizeOption,
        FontSizeOption.large,
      );
      expect(prefs.getString('theme_font_size'), 'large');
    },
  );

  for (final replacement in [
    'B/gen1/dev/endpoint1',
    'A/gen2/dev/endpoint1',
    'A/gen1/other/endpoint1',
    'A/gen1/dev/endpoint2',
  ]) {
    test(
      'queued account restore rejects replaced owner $replacement',
      () async {
        final theme = await ready();
        final fake = await store();
        fake.delayKey = 'flutter.theme_font_size';
        final choosing = theme.updateFontSizeOption(FontSizeOption.huge);
        await fake.entered.future.timeout(const Duration(seconds: 2));
        var owner = 'A/gen1/dev/endpoint1';
        final captured = owner;
        final restoring = theme.restoreAccountFontSize(
          'small',
          expectedRevision: theme.fontRequestRevision,
          isCurrent: () => owner == captured,
        );
        owner = replacement;
        fake.release.complete();
        await Future.wait([choosing, restoring]);
        expect(
          container.read(themeProvider).fontSizeOption,
          FontSizeOption.huge,
        );
        expect(prefs.getString('theme_font_size'), 'huge');
      },
    );
  }
}
