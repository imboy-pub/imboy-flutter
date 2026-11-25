import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: deprecated_member_use
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart' show envMap;
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';

import 'set_region_page_widget_support.dart';

void main() {
  setUpAll(prepareWebWriter);

  // Start the singleton auth write queue inside this widget test's zone.
  testWidgets(
    'preview clears prior region and draft when the auth generation changes',
    (tester) async {
      const previousRegion = 'Previous session region';
      final repo = UserRepoLocal.to;
      await pumpEditorHarness(
        tester,
        editorBuilder: () => SetRegionPage(
          title: t.common.setRegion,
          currentValue: previousRegion,
          onSave: (_) async => throw StateError('legacy save is disabled'),
          onSaveSelection: (_) async =>
              throw StateError('revoked preview must not save'),
          canSavePreview: () => true,
        ),
        previewSource: () async => FakeGeoSource(),
        rejectLegacyProvider: true,
        mockPreferences: const {Keys.currentUid: '1001'},
      );
      expect(find.text(previousRegion), findsWidgets);
      await drillToShibuya(tester);
      await tapPickerRow(tester, 'confirm-selection');
      expect(find.text('日本 東京都 渋谷区'), findsWidgets);

      // Reject the first durable login write on the same in-memory
      // preferences seam as qr_login_persistence_test, before plugin I/O.
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = RejectLoginRegistry();
      SharedPreferencesStorePlatform.instance = store;
      addTearDown(() {
        SharedPreferencesStorePlatform.instance = previousStore;
        if (!store.releaseRegistry.isCompleted) {
          store.releaseRegistry.complete();
        }
        if (repo.isAuthTransitionFailed) {
          repo.clearAuthTransitionFailureForTest();
        }
      });
      final owner = authSessionReader.current;
      expect(authSessionReader.isCurrent(owner), isTrue);
      final replacing = repo.loginAfterQr(
        uid: owner.uid,
        token: 'synthetic-geo-session-token',
      );
      expect(repo.sessionGeneration, owner.generation + 1);
      expect(authSessionReader.current.transitioning, isTrue);
      final rejected = expectLater(
        replacing,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Could not save preference',
          ),
        ),
      );
      // The auth listener must schedule a repaint without an extra UI action.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(store.registryEntered.isCompleted, isTrue);
      expect(authSessionReader.current.uid, owner.uid);
      expect(authSessionReader.current.transitioning, isTrue);

      expect(find.text(previousRegion), findsNothing);
      expect(find.text('日本 東京都 渋谷区'), findsNothing);
      expect(find.byType(GeoRegionPicker), findsNothing);
      final done = find.ancestor(
        of: find.text(t.common.buttonAccomplish),
        matching: find.byType(CupertinoButton),
      );
      expect(tester.widget<CupertinoButton>(done).onPressed, isNull);

      store.releaseRegistry.complete();
      await tester.pump();
      expect(authSessionReader.transitionFailed, isTrue);
      await rejected;
    },
  );

  testWidgets(
    'legacy cache only enriches the current profile in the owning environment',
    (tester) async {
      final previousEnv = currentEnv;
      final previousLocal = envMap['local']!;
      envMap['local'] = envMap['dev']!;
      addTearDown(() {
        envMap['local'] = previousLocal;
        currentEnv = previousEnv;
      });
      currentEnv = 'local';
      const sameProfile = 'New South Wales Sydney';
      const savedPath = ['New South Wales', 'Sydney'];
      Future<void> open(String profile, {bool reuse = true}) =>
          pumpEditorHarness(
            tester,
            editorBuilder: () => SetRegionPage(
              title: '地区',
              currentValue: profile,
              onSave: (_) async => true,
            ),
            reusePreferences: reuse,
            mockPreferences: const {
              'region_selected': '无归属的旧地区',
              'region_path': '无归属 旧路径',
            },
          );
      await open(sameProfile, reuse: false);
      final owner = AccountPreferences.capture();
      await RegionCache.saveSelection(owner, sameProfile, savedPath);
      await open(sameProfile);
      expect(
        regionTestContainer(tester).read(setRegionProvider).regionPath,
        savedPath,
      );

      await StorageService.to.setString(Keys.currentUid, 'geo-test-B');
      await open('中国香港 中西区');
      final b = regionTestContainer(tester).read(setRegionProvider);
      expect(b.selectedRegion, '中国香港 中西区');
      expect(b.regionPath, ['中国香港', '中西区']);
      expect(
        AccountPreferences.capture().readList(
          RegionCache.legacySelectionPreferenceKey,
        ),
        isEmpty,
      );

      await StorageService.to.setString(Keys.currentUid, 'geo-test-A');
      currentEnv = 'dev';
      await open(sameProfile);
      expect(regionTestContainer(tester).read(setRegionProvider).regionPath, [
        'New',
        'South',
        'Wales',
        'Sydney',
      ]);
      expect(
        AccountPreferences.capture().readList(
          RegionCache.legacySelectionPreferenceKey,
        ),
        isEmpty,
      );

      currentEnv = 'local';
      await open(sameProfile);
      expect(
        regionTestContainer(tester).read(setRegionProvider).regionPath,
        savedPath,
      );
      expect(await RegionCache.loadSelectedRegion(), '无归属的旧地区');
      expect(await RegionCache.loadRegionPath(), ['无归属', '旧路径']);
    },
  );

  testWidgets(
    'legacy save completion from a revoked editor cannot write into either account',
    (tester) async {
      final response = Completer<bool>();
      var saves = 0;
      await pumpRegionFlow(
        tester,
        onSave: (_) {
          saves++;
          return response.future;
        },
      );
      final owner = AccountPreferences.capture().owner;
      await selectBeijingDongcheng(tester);
      final save = find.text(t.common.buttonAccomplish);
      await tester.tap(save);
      await tester.pump();
      expect(saves, 1);

      await StorageService.to.setString(Keys.currentUid, 'geo-test-B');
      response.complete(true);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
      expect(
        StorageService.to.getStringList(
          owner.preferenceKey(RegionCache.legacySelectionPreferenceKey),
        ),
        isNull,
      );
      expect(
        AccountPreferences.capture().readList(
          RegionCache.legacySelectionPreferenceKey,
        ),
        isEmpty,
      );
      expect(await RegionCache.loadSelectedRegion(), isEmpty);
    },
  );

  test(
    'account-scoped Geo entry requires opt-in and the same self session',
    () {
      const owner = UserProfileSessionSnapshot(
        uid: '10',
        generation: 1,
        environment: 'local',
        endpoint: 'http://127.0.0.1:9814',
      );
      const relogin = UserProfileSessionSnapshot(
        uid: '10',
        generation: 2,
        environment: 'local',
        endpoint: 'http://127.0.0.1:9814',
      );

      bool canOpen({
        UserProfileSessionSnapshot? entry = owner,
        UserProfileSessionSnapshot current = owner,
        String displayedUid = '10',
        bool ready = true,
        bool configured = true,
      }) => canOpenSelfGeoPreview(
        owner: entry,
        current: current,
        displayedUid: displayedUid,
        sessionReady: ready,
        previewConfigured: configured,
      );

      expect(canOpen(), isTrue);
      expect(canOpen(entry: null), isFalse);
      expect(canOpen(configured: false), isFalse);
      expect(canOpen(ready: false), isFalse);
      expect(canOpen(displayedUid: '11'), isFalse);
      expect(
        canOpen(
          current: const UserProfileSessionSnapshot(
            uid: '10',
            generation: 1,
            environment: 'local',
            endpoint: 'http://127.0.0.1:9819',
          ),
        ),
        isFalse,
      );
      expect(canOpen(current: relogin), isFalse);
    },
  );

  test(
    'Web preview stays disabled by default and rejects non-loopback origins',
    () {
      final local = Uri.parse('http://127.0.0.1:9817/app/');
      final remote = Uri.parse('https://app.example.test/app/');
      expect(
        localGeoPreviewRequested(
          enabled: false,
          isWeb: true,
          environment: 'local',
          appUri: local,
        ),
        isFalse,
      );
      expect(
        localGeoPreviewRequested(
          enabled: true,
          isWeb: true,
          environment: 'local',
          appUri: remote,
        ),
        isFalse,
      );
      expect(isLoopbackGeoPreviewUri(remote), isFalse);
      expect(
        isLoopbackGeoPreviewUri(Uri.parse('http://127.0.0.1:9816')),
        isTrue,
      );
    },
  );

  testWidgets('递归下钻保留完整父级路径，切换地区不残留旧路径', (tester) async {
    await pumpRegionFlow(tester, onSave: (_) async => true);
    await selectBeijingDongcheng(tester);

    var state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国大陆 北京 东城');
    expect(state.regionPath, ['中国大陆', '北京', '东城']);

    await popRegionRoute(tester);
    await popRegionRoute(tester);
    await tapRegion(tester, '中国香港');
    await tapRegion(tester, '中西区');

    state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);

    await tester.tap(find.text('中西区'));
    await tester.pump();
    state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);
  });

  testWidgets('保存失败保持递归页面且不提前写入已提交缓存', (tester) async {
    String? attemptedValue;
    await pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return false;
      },
    );
    await selectBeijingDongcheng(tester);

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(attemptedValue, '中国大陆 北京 东城');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
    expect(find.text('东城'), findsOneWidget);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(legacySelectionKey()), isNull);
  });

  testWidgets('保存成功退出所有递归页面并提交一致的地区缓存', (tester) async {
    String? savedValue;
    await pumpRegionFlow(
      tester,
      onSave: (value) async {
        savedValue = value;
        return true;
      },
    );
    await selectBeijingDongcheng(tester);

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(savedValue, '中国大陆 北京 东城');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsNothing);
    expect(find.text('MorePage'), findsOneWidget);
    expect(
      AccountPreferences.capture().readList(
        RegionCache.legacySelectionPreferenceKey,
      ),
      ['中国大陆 北京 东城', '中国大陆', '北京', '东城'],
    );
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
  });

  // ── FL-11 负例（先证明既有合同，再决定允许路径改动）──────────────────

  testWidgets('取消不保存：下钻选中后直接返回，不触发保存也不写缓存', (tester) async {
    String? attemptedValue;
    await pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return true;
      },
    );
    await selectBeijingDongcheng(tester);

    // 未点「完成」，逐层退出整个地区编辑流程（等价于用户放弃草稿）。
    await popRegionRoute(tester);
    await popRegionRoute(tester);
    await popRegionRoute(tester);
    await tester.pumpAndSettle();

    expect(attemptedValue, isNull, reason: '取消不得触发保存回调');
    expect(find.text('MorePage'), findsOneWidget);
    expect(
      await RegionCache.loadSelectedRegion(),
      isEmpty,
      reason: '取消不得写已提交缓存',
    );
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(legacySelectionKey()), isNull);
  });

  testWidgets('切语言不触发保存：编辑中切换语言，草稿保留且不提交缓存', (tester) async {
    String? attemptedValue;
    await pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return true;
      },
    );
    await selectBeijingDongcheng(tester);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));

    // 延迟加载 locale 需 runAsync（仓内既定模式，见
    // message_multi_select_action_bar_test.dart）。
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.enUs));
    await tester.pumpAndSettle();

    expect(attemptedValue, isNull, reason: '语言变化不得触发保存');
    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国大陆 北京 东城', reason: '草稿不因语言切换丢失');
    expect(state.hasChanged, isTrue);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
  });

  testWidgets('缓存损坏：损坏列表缓存不得进入活动状态，权威资产自愈且页面不崩溃', (tester) async {
    // 生产 Provider（无 fixture override）：损坏缓存 + 真实资产回源。
    await pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: '地区',
        currentValue: '',
        onSave: (_) async => true,
      ),
      useProductionProvider: true,
      mockPreferences: <String, Object>{
        'region_list': '{corrupt-json',
        'region_selected': '中国大陆 北京 东城',
        'region_path': '中国大陆 北京 东城',
      },
    );

    // 页面仍然存活：损坏缓存解析失败返回空列表后，资产回源接管列表。
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
    expect(find.text('中国大陆'), findsOneWidget, reason: '权威资产数据接管列表');

    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.regionList, isNotEmpty, reason: '损坏缓存不得使页面失数据');
    expect(state.selectedRegion, isEmpty, reason: '无归属旧选择不能替代空资料');
    expect(await RegionCache.loadSelectedRegion(), '中国大陆 北京 东城');

    // 损坏字节被权威资产覆盖自愈：回写内容可解析为列表。
    final prefs = await SharedPreferences.getInstance();
    final healed = jsonDecode(prefs.getString('region_list') ?? '');
    expect(healed, isA<List<dynamic>>());
    expect((healed as List<dynamic>).first['title'], '中国大陆');
  });

  // ── FL-11 结构化模式：geo_regions 选择器接入（AC-88/89/91）─────────────
}
