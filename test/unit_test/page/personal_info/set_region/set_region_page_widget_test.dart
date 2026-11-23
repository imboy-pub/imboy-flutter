import 'dart:async';
import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as picker_material;
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    as picker_l10n;
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
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/theme/default/font_types.dart';

class _RejectLoginRegistry extends InMemorySharedPreferencesStore {
  _RejectLoginRegistry()
    : super.withData({'flutter.${Keys.currentUid}': '1001'});

  final registryEntered = Completer<void>();
  final releaseRegistry = Completer<void>();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == 'flutter.${LoginAccountHistoryService.storageKey}') {
      registryEntered.complete();
      await releaseRegistry.future;
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

const _regionFixture = [
  {
    'title': '中国大陆',
    'children': [
      {
        'title': '北京',
        'children': ['东城'],
      },
    ],
  },
  {
    'title': '中国香港',
    'children': ['中西区'],
  },
];

/// 固定地区树仅注入测试；路径、保存和缓存逻辑使用生产 Notifier。
class _FixtureRegionNotifier extends SetRegionNotifier {
  @override
  SetRegionState build() => const SetRegionState(regionList: _regionFixture);
}

class _UnusedLegacyRegionNotifier extends SetRegionNotifier {
  @override
  SetRegionState build() =>
      throw StateError('preview used the legacy provider');
}

/// 测试根壳：镜像 run.dart:198 的语言切换重建机制。应用使用全局 `t`
/// （strings.g.dart:222，无 context 依赖），整树重建靠根壳监听
/// LocaleSettings.getLocaleStream 并把新 locale 传给 MaterialApp；
/// 测试不复刻该机制则被测页面不会随 LocaleSettings 变化重建。
class _LocaleRebuildHarness extends StatefulWidget {
  const _LocaleRebuildHarness({required this.child});

  final Widget child;

  @override
  State<_LocaleRebuildHarness> createState() => _LocaleRebuildHarnessState();
}

class _LocaleRebuildHarnessState extends State<_LocaleRebuildHarness> {
  AppLocale _locale = LocaleSettings.currentLocale;
  StreamSubscription<AppLocale>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = LocaleSettings.getLocaleStream().listen((locale) {
      if (mounted && _locale != locale) {
        setState(() => _locale = locale);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TranslationProvider(
      child: MaterialApp(
        locale: _locale.flutterLocale,
        supportedLocales: AppLocaleUtils.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          // ignore: deprecated_member_use
          picker_l10n.GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: widget.child,
      ),
    );
  }
}

/// 编辑器打开流程的公共壳：卸载旧树、清空 mock prefs、从 MorePage 打开
/// [editorBuilder] 构造的 SetRegionPage。fixture provider 默认注入；
/// [useProductionProvider] 走生产 Notifier（缓存损坏负例用真实资产回源）。
/// 不依赖 rootBundle/缓存回填；真实资产加载由 AT-MF06 集成验收覆盖。
Future<void> _pumpEditorHarness(
  WidgetTester tester, {
  required SetRegionPage Function() editorBuilder,
  Map<String, Object>? mockPreferences,
  bool useProductionProvider = false,
  bool reusePreferences = false,
  Future<GeoRegionDataSource?> Function()? previewSource,
  Future<GeoRegionDataSource?> Function()? androidQaSource,
  bool rejectLegacyProvider = false,
  bool noCurrentAccount = false,
}) async {
  // 前一测试可能仍停留在递归子页面。显式卸载 Navigator 和
  // autoDispose Provider，避免第二、第三个 Widget 测试复用旧状态。
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  if (!reusePreferences) {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: 'geo-test-A',
      ...?mockPreferences,
    });
    await StorageService.init();
  }
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        if (noCurrentAccount) currentUserProvider.overrideWithValue(null),
        if (rejectLegacyProvider)
          setRegionProvider.overrideWith(_UnusedLegacyRegionNotifier.new)
        else if (!useProductionProvider)
          setRegionProvider.overrideWith(_FixtureRegionNotifier.new),
        if (previewSource != null)
          geoRegionPreviewSourceProvider.overrideWith((_) => previewSource()),
        if (androidQaSource != null)
          androidGeoQaSourceProvider.overrideWith((_) => androidQaSource()),
      ],
      child: _LocaleRebuildHarness(
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              key: const Key('open-region-editor'),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute<void>(builder: (_) => editorBuilder()),
                );
              },
              child: const Text('MorePage'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open-region-editor')));
  await tester.pumpAndSettle();
}

Future<void> _pumpRegionFlow(
  WidgetTester tester, {
  required Future<bool> Function(String) onSave,
}) async {
  await _pumpEditorHarness(
    tester,
    editorBuilder: () =>
        SetRegionPage(title: '地区', currentValue: '', onSave: onSave),
  );
  await _waitForRegionData(tester);
}

Future<void> _waitForRegionData(WidgetTester tester) async {
  final mainland = find.text('中国大陆');
  await tester.pump();
  expect(mainland, findsOneWidget, reason: '地区测试夹具应显示中国大陆');
}

Future<void> _tapRegion(WidgetTester tester, String title) async {
  final finder = find.text(title);
  for (var attempt = 0; attempt < 40; attempt++) {
    if (finder.evaluate().isNotEmpty) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
  }
  expect(finder, findsOneWidget, reason: '地区列表应显示 $title');
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _popRegionRoute(WidgetTester tester) async {
  // IosPageTemplate 使用 GlassBackButton，而不是 Cupertino 默认返回按钮；
  // 直接 pop 当前 Navigator，避免 WidgetTester.pageBack 的组件类型假设。
  final rootPage = find.byType(SetRegionPage, skipOffstage: false);
  Navigator.of(tester.element(rootPage)).pop();
  await tester.pumpAndSettle();
}

Future<void> _selectBeijingDongcheng(WidgetTester tester) async {
  await _tapRegion(tester, '中国大陆');
  await _tapRegion(tester, '北京');
  await _tapRegion(tester, '东城');
}

ProviderContainer _container(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(SetRegionPage, skipOffstage: false)),
  );
}

String _legacySelectionKey() => AccountPreferences.capture().owner
    .preferenceKey(RegionCache.legacySelectionPreferenceKey);

/// geo_regions 选择器的内存数据源：pathIds 只从这份固定数据集产生，
/// 页面/Provider 绝不反推 ID。标签表按包内 alias 规范键控（kGeoLocaleAliases）。
class _FakeGeoSource implements GeoRegionDataSource {
  _FakeGeoSource();

  /// 页面传给数据源的原始 displayLocale（显式映射断言用）。
  final List<String> requestedLocales = <String>[];
  final List<String> resolvedLabelLocales = <String>[];

  /// 置 true 模拟数据源不可用（离线失败路径）。
  bool failCountryLoad = false;

  static const datasetId = 'geo-regions-seed';
  static const revision = 's-0000000000000000';
  static const rootId = 'cc:JP';
  static const tokyoId = 'jp:13';
  static const shibuyaId = 'jp:13103';
  static const blankId = 'jp:blank';
  static const unknownWardId = 'jp:unknown-ward';

  static const _labels = <String, Map<String, String>>{
    rootId: {'zh-Hans': '日本', 'en': 'Japan', 'ja': '日本', 'ar': 'اليابان'},
    tokyoId: {'zh-Hans': '東京都', 'en': 'Tokyo', 'ja': '東京', 'ar': 'طوكيو'},
    shibuyaId: {
      'zh-Hans': '渋谷区',
      'en': 'Shibuya',
      'ja': '渋谷区',
      // 长名 + Unicode：阿语长名在行内完整渲染（AC-89 可用性）。
      'ar': 'منطقة شيبويا الإدارية — تستخدم للتحقق من الأسماء الطويلة جداً داخل منتقي المناطق',
    },
    blankId: {'zh-Hans': '', 'en': '', 'ja': '', 'ar': ''},
    unknownWardId: {
      'zh-Hans': '未知辖区',
      'en': 'Unknown ward',
      'ja': '不明区',
      'ar': 'حي مجهول',
    },
  };

  static const _dataset = <String, (GeoChildrenStatus, bool)>{
    rootId: (GeoChildrenStatus.complete, true),
    tokyoId: (GeoChildrenStatus.complete, true),
    shibuyaId: (GeoChildrenStatus.complete, false),
    blankId: (GeoChildrenStatus.complete, false),
    unknownWardId: (GeoChildrenStatus.unknown, false),
  };

  String _localeKey(String locale) => kGeoLocaleAliases[locale] ?? locale;

  String _label(String id, String locale) {
    final key = _localeKey(locale);
    return _labels[id]?[key] ?? _labels[id]?['en'] ?? '';
  }

  GeoPickerItem _item(String id, String locale) {
    final (status, hasChildren) = _dataset[id]!;
    return GeoPickerItem(
      nodeId: id,
      label: _label(id, locale),
      countryCode: 'JP',
      isCountryRoot: id == rootId,
      childrenStatus: status,
      hasChildren: hasChildren,
      pathIds: [id],
      availability: GeoPickerAvailability.bundled,
    );
  }

  @override
  Future<List<GeoPickerItem>> loadCountries(String locale) async {
    requestedLocales.add(locale);
    if (failCountryLoad) {
      throw const GeoNetworkError('offline: countries unavailable');
    }
    return [_item(rootId, locale)];
  }

  @override
  Future<GeoPickerCountryContent> openCountry(
    String countryCode,
    String locale,
  ) async {
    requestedLocales.add(locale);
    final root = _item(rootId, locale);
    return GeoPickerCountryContent(
      root: root,
      children: [_item(tokyoId, locale), _item(unknownWardId, locale)],
    );
  }

  @override
  Future<List<GeoPickerItem>> loadChildren(
    String countryCode,
    String nodeId,
    String locale,
  ) async {
    requestedLocales.add(locale);
    if (nodeId == rootId) {
      return [_item(tokyoId, locale), _item(unknownWardId, locale)];
    }
    if (nodeId == tokyoId) {
      return [_item(shibuyaId, locale), _item(blankId, locale)];
    }
    return const <GeoPickerItem>[];
  }

  @override
  Future<List<GeoPickerItem>> search(String query, String locale) async =>
      const <GeoPickerItem>[];

  @override
  Future<GeoSelection> resolveSelection(
    List<String> pathIds, {
    required GeoSelectionPolicy policy,
    String? displayLocale,
  }) async {
    // 未知路径抛类型化异常：不猜映射（FL-09 裁决点③ 的镜像）。
    for (final id in pathIds) {
      if (!_dataset.containsKey(id)) {
        throw GeoParseFailureError('unknown node: $id');
      }
    }
    return GeoSelection(
      protocolVersion: '1.0',
      datasetId: datasetId,
      countryCode: 'JP',
      dataRevision: revision,
      pathIds: List<String>.of(pathIds),
      displaySnapshot: [
        for (final id in pathIds) _label(id, displayLocale ?? 'en'),
      ],
      displayLocale: displayLocale,
    );
  }

  @override
  Future<Map<String, GeoPickerLabelInfo>> resolveLabels(
    List<String> nodeIds,
    String locale,
  ) async {
    resolvedLabelLocales.add(locale);
    return {
      for (final id in nodeIds)
        id: GeoPickerLabelInfo(text: _label(id, locale)),
    };
  }

  @override
  GeoPickerAvailability availabilityOf(String countryCode) =>
      GeoPickerAvailability.bundled;
}

Future<void> _pumpGeoRegionFlow(
  WidgetTester tester, {
  required _FakeGeoSource source,
  required Future<bool> Function(GeoSelection selection) onSaveSelection,
}) async {
  await _pumpEditorHarness(
    tester,
    editorBuilder: () => SetRegionPage(
      title: '地区',
      currentValue: '',
      onSave: (_) async => true,
      geoDataSource: source,
      onSaveSelection: onSaveSelection,
    ),
  );
}

/// 滚动到可见再点击：长名/多级下钻时行可能超出默认测试视口。
Future<void> _tapPickerRow(WidgetTester tester, String keyId) async {
  final finder = find.byKey(ValueKey(keyId));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _drillToShibuya(WidgetTester tester) async {
  await _tapPickerRow(tester, 'country-${_FakeGeoSource.rootId}');
  await _tapPickerRow(tester, 'node-${_FakeGeoSource.tokyoId}');
  await _tapPickerRow(tester, 'node-${_FakeGeoSource.shibuyaId}');
}

void main() {
  setUpAll(prepareWebWriter);

  // Start the singleton auth write queue inside this widget test's zone.
  testWidgets(
    'preview clears prior region and draft when the auth generation changes',
    (tester) async {
      const previousRegion = 'Previous session region';
      final repo = UserRepoLocal.to;
      await _pumpEditorHarness(
        tester,
        editorBuilder: () => SetRegionPage(
          title: t.common.setRegion,
          currentValue: previousRegion,
          onSave: (_) async => throw StateError('legacy save is disabled'),
          onSaveSelection: (_) async =>
              throw StateError('revoked preview must not save'),
          canSavePreview: () => true,
        ),
        previewSource: () async => _FakeGeoSource(),
        rejectLegacyProvider: true,
        mockPreferences: const {Keys.currentUid: '1001'},
      );
      expect(find.text(previousRegion), findsWidgets);
      await _drillToShibuya(tester);
      await _tapPickerRow(tester, 'confirm-selection');
      expect(find.text('日本 東京都 渋谷区'), findsWidgets);

      // Reject the first durable login write on the same in-memory
      // preferences seam as qr_login_persistence_test, before plugin I/O.
      final previousStore = SharedPreferencesStorePlatform.instance;
      final store = _RejectLoginRegistry();
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
          _pumpEditorHarness(
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
      expect(_container(tester).read(setRegionProvider).regionPath, savedPath);

      await StorageService.to.setString(Keys.currentUid, 'geo-test-B');
      await open('中国香港 中西区');
      final b = _container(tester).read(setRegionProvider);
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
      expect(_container(tester).read(setRegionProvider).regionPath, [
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
      expect(_container(tester).read(setRegionProvider).regionPath, savedPath);
      expect(await RegionCache.loadSelectedRegion(), '无归属的旧地区');
      expect(await RegionCache.loadRegionPath(), ['无归属', '旧路径']);
    },
  );

  testWidgets(
    'legacy save completion from a revoked editor cannot write into either account',
    (tester) async {
      final response = Completer<bool>();
      var saves = 0;
      await _pumpRegionFlow(
        tester,
        onSave: (_) {
          saves++;
          return response.future;
        },
      );
      final owner = AccountPreferences.capture().owner;
      await _selectBeijingDongcheng(tester);
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
    await _pumpRegionFlow(tester, onSave: (_) async => true);
    await _selectBeijingDongcheng(tester);

    var state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国大陆 北京 东城');
    expect(state.regionPath, ['中国大陆', '北京', '东城']);

    await _popRegionRoute(tester);
    await _popRegionRoute(tester);
    await _tapRegion(tester, '中国香港');
    await _tapRegion(tester, '中西区');

    state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);

    await tester.tap(find.text('中西区'));
    await tester.pump();
    state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国香港 中西区');
    expect(state.regionPath, ['中国香港', '中西区']);
  });

  testWidgets('保存失败保持递归页面且不提前写入已提交缓存', (tester) async {
    String? attemptedValue;
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return false;
      },
    );
    await _selectBeijingDongcheng(tester);

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(attemptedValue, '中国大陆 北京 东城');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
    expect(find.text('东城'), findsOneWidget);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(_legacySelectionKey()), isNull);
  });

  testWidgets('保存成功退出所有递归页面并提交一致的地区缓存', (tester) async {
    String? savedValue;
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        savedValue = value;
        return true;
      },
    );
    await _selectBeijingDongcheng(tester);

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
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return true;
      },
    );
    await _selectBeijingDongcheng(tester);

    // 未点「完成」，逐层退出整个地区编辑流程（等价于用户放弃草稿）。
    await _popRegionRoute(tester);
    await _popRegionRoute(tester);
    await _popRegionRoute(tester);
    await tester.pumpAndSettle();

    expect(attemptedValue, isNull, reason: '取消不得触发保存回调');
    expect(find.text('MorePage'), findsOneWidget);
    expect(
      await RegionCache.loadSelectedRegion(),
      isEmpty,
      reason: '取消不得写已提交缓存',
    );
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(_legacySelectionKey()), isNull);
  });

  testWidgets('切语言不触发保存：编辑中切换语言，草稿保留且不提交缓存', (tester) async {
    String? attemptedValue;
    await _pumpRegionFlow(
      tester,
      onSave: (value) async {
        attemptedValue = value;
        return true;
      },
    );
    await _selectBeijingDongcheng(tester);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));

    // 延迟加载 locale 需 runAsync（仓内既定模式，见
    // message_multi_select_action_bar_test.dart）。
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.enUs));
    await tester.pumpAndSettle();

    expect(attemptedValue, isNull, reason: '语言变化不得触发保存');
    final state = _container(tester).read(setRegionProvider);
    expect(state.selectedRegion, '中国大陆 北京 东城', reason: '草稿不因语言切换丢失');
    expect(state.hasChanged, isTrue);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
  });

  testWidgets('缓存损坏：损坏列表缓存不得进入活动状态，权威资产自愈且页面不崩溃', (tester) async {
    // 生产 Provider（无 fixture override）：损坏缓存 + 真实资产回源。
    await _pumpEditorHarness(
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

    final state = _container(tester).read(setRegionProvider);
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

  testWidgets('Geo discard dialog cancels or clears a draft without saving', (
    tester,
  ) async {
    final previousLocale = LocaleSettings.currentLocale;
    LocaleSettings.setLocaleSync(AppLocale.zhCn);
    addTearDown(() => LocaleSettings.setLocaleSync(previousLocale));
    var saves = 0;
    Future<bool> recordSave(Object _) async {
      saves++;
      return true;
    }

    await _pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: t.common.setRegion,
        currentValue: '',
        onSave: recordSave,
        onSaveSelection: recordSave,
        canSavePreview: () => true,
      ),
      rejectLegacyProvider: true,
      previewSource: () async => _FakeGeoSource(),
    );
    await _drillToShibuya(tester);

    final draft = find.text('cc:JP / jp:13 / jp:13103');
    final dialog = find.byType(picker_material.AlertDialog);
    Finder dialogAction(String label) =>
        find.descendant(of: dialog, matching: find.text(label));

    expect(draft, findsOneWidget);
    await _tapPickerRow(tester, 'discard-button');
    expect(tester.takeException(), isNull);
    expect(dialogAction('放弃尚未确认的选择？'), findsOneWidget);
    await tester.tap(dialogAction('继续选择'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(draft, findsOneWidget);

    await _tapPickerRow(tester, 'discard-button');
    await tester.tap(dialogAction('放弃修改'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(dialog, findsNothing);
    expect(draft, findsNothing);
    expect(
      find.byKey(const ValueKey('country-${_FakeGeoSource.rootId}')),
      findsOneWidget,
    );
    expect(saves, 0);
  });

  testWidgets('默认数据源打开结构化预览，错误 pin 阻止保存', (tester) async {
    var saveCalls = 0;

    SetRegionPage editor() => SetRegionPage(
      title: t.common.setRegion,
      currentValue: '',
      onSave: (_) async {
        saveCalls++;
        return true;
      },
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
      canSavePreview: () => true,
    );

    await _pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async => _FakeGeoSource(),
    );
    final picker = find.byType(GeoRegionPicker);
    expect(picker, findsOneWidget);
    final pickerTheme = picker_material.Theme.of(tester.element(picker));
    final previewFontFallback = [
      kAppFontFamilyFallback.first,
      'IMBoyGeoCjk',
      'NotoSansArabicGeo',
      ...kAppFontFamilyFallback.skip(1),
    ];
    expect(
      pickerTheme.textTheme.bodyMedium?.fontFamilyFallback,
      previewFontFallback,
    );
    expect(
      pickerTheme.primaryTextTheme.bodyMedium?.fontFamilyFallback,
      previewFontFallback,
    );
    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    expect(find.text('日本 東京都 渋谷区'), findsWidgets);

    await _pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async {
        throw const GeoIntegrityMismatchError('invalid preview pin');
      },
    );
    expect(find.byType(GeoRegionPicker), findsNothing);
    expect(
      find.text('${t.common.setRegion} · ${t.common.error}'),
      findsOneWidget,
    );
    final saveButton = find.ancestor(
      of: find.text(t.common.buttonAccomplish),
      matching: find.byType(CupertinoButton),
    );
    expect(tester.widget<CupertinoButton>(saveButton).onPressed, isNull);
    expect(saveCalls, 0);
  });

  testWidgets('只读资料预览无数据源不降级，切号后旧草稿不得保存', (tester) async {
    const previousRegion = 'Previous account region';
    var ownerStillCurrent = true;
    var saveCalls = 0;
    SetRegionPage editor() => SetRegionPage(
      title: t.common.setRegion,
      currentValue: previousRegion,
      onSave: (_) async {
        saveCalls++;
        return true;
      },
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
      canSavePreview: () => ownerStillCurrent,
    );

    await _pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async => null,
    );
    expect(find.byType(GeoRegionPicker), findsNothing);
    expect(find.text('中国大陆'), findsNothing);
    expect(
      find.text('${t.common.setRegion} · ${t.common.error}'),
      findsOneWidget,
    );

    await _pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async => _FakeGeoSource(),
    );
    expect(find.text(previousRegion), findsWidgets);
    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    expect(find.text('日本 東京都 渋谷区'), findsWidgets);
    ownerStillCurrent = false;
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(find.text(previousRegion), findsNothing);
    expect(find.text('日本 東京都 渋谷区'), findsNothing);
    expect(find.byType(GeoRegionPicker), findsNothing);
    expect(
      find.text('${t.common.setRegion} · ${t.common.error}'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Android QA direct route without a self session never loads or falls back',
    (tester) async {
      const previousRegion = 'Previous account region';
      var legacySaves = 0;
      var webLoads = 0;
      var androidLoads = 0;
      await _pumpEditorHarness(
        tester,
        editorBuilder: () => SetRegionPage(
          title: t.common.setRegion,
          currentValue: previousRegion,
          androidGeoQa: true,
          onSave: (_) async {
            legacySaves++;
            return true;
          },
        ),
        rejectLegacyProvider: true,
        noCurrentAccount: true,
        androidQaSource: () async {
          androidLoads++;
          return _FakeGeoSource();
        },
        previewSource: () async {
          webLoads++;
          return _FakeGeoSource();
        },
      );
      expect(find.byType(GeoRegionPicker), findsNothing);
      expect(find.text('中国大陆'), findsNothing);
      expect(find.text(previousRegion), findsNothing);
      expect(find.text(t.common.selectedRegion.toUpperCase()), findsNothing);
      expect(find.byIcon(CupertinoIcons.refresh), findsNothing);
      expect(
        find.text('${t.common.setRegion} · ${t.common.error}'),
        findsOneWidget,
      );
      final done = find.ancestor(
        of: find.text(t.common.buttonAccomplish),
        matching: find.byType(CupertinoButton),
      );
      expect(tester.widget<CupertinoButton>(done).onPressed, isNull);
      expect(legacySaves, 0);
      expect(webLoads, 0);
      expect(androidLoads, 0);
    },
  );

  testWidgets('Web 结构化保存及切号不读写全局 legacy 地区缓存', (tester) async {
    const legacySelection = '旧的全局地区';
    const legacyPath = '旧的 全局 地区';
    const legacyCache = {
      'region_selected': legacySelection,
      'region_path': legacyPath,
    };
    final accountSelections = <String, GeoSelection>{};

    Future<void> open(
      String uid,
      String currentValue, {
      Map<String, Object>? preferences,
    }) => _pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: t.common.setRegion,
        currentValue: currentValue,
        onSave: (_) async => throw StateError('legacy save is disabled'),
        onSaveSelection: (selection) async {
          accountSelections[uid] = selection;
          return true;
        },
        canSavePreview: () => true,
      ),
      previewSource: () async => _FakeGeoSource(),
      mockPreferences: preferences,
      rejectLegacyProvider: true,
    );

    await open('A', '账号 A 的地区', preferences: legacyCache);
    expect(find.text('账号 A 的地区'), findsWidgets);
    expect(find.text(legacySelection), findsNothing);
    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(accountSelections['A']?.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('region_selected'), legacySelection);
    expect(prefs.getString('region_path'), legacyPath);

    await open(
      'B',
      '账号 B 的地区',
      preferences: {
        'region_selected': prefs.getString('region_selected')!,
        'region_path': prefs.getString('region_path')!,
      },
    );
    expect(find.text('账号 B 的地区'), findsWidgets);
    expect(find.text(legacySelection), findsNothing);
    expect(find.text('日本 東京都 渋谷区'), findsNothing);
    expect(accountSelections.keys, ['A']);
  });

  testWidgets('结构化保存：pathIds 来自数据集，服务端成功后才提交缓存并退出', (tester) async {
    final source = _FakeGeoSource();
    GeoSelection? savedSelection;
    String? cacheAtSaveTime;
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (selection) async {
        saveCalls++;
        cacheAtSaveTime = AccountPreferences.capture()
            .readList(RegionCache.legacySelectionPreferenceKey)
            .join(' ');
        savedSelection = selection;
        return true;
      },
    );

    // locale 映射显式：zhCn → 'zh-CN'。
    expect(source.requestedLocales, contains('zh-CN'));

    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection, isNotNull);
    expect(state.geoSelection!.pathIds, [
      'cc:JP',
      'jp:13',
      'jp:13103',
    ], reason: 'pathIds 必须来自 pinned 数据集的真实下钻');
    expect(state.selectedRegion, '日本 東京都 渋谷区');
    expect(state.hasChanged, isTrue);
    expect(cacheAtSaveTime, isNull, reason: '确认草稿不等于保存：此刻尚未触发服务端保存');

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(savedSelection!.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);
    expect(cacheAtSaveTime, isEmpty, reason: '服务端保存成功前不得提交缓存');
    expect(find.byType(SetRegionPage, skipOffstage: false), findsNothing);
    expect(find.text('MorePage'), findsOneWidget);
    // 保存成功后的回显缓存：只含权威展示串/标签，不含猜测内容。
    expect(
      AccountPreferences.capture().readList(
        RegionCache.legacySelectionPreferenceKey,
      ),
      ['日本 東京都 渋谷区', '日本', '東京都', '渋谷区'],
    );
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
  });

  testWidgets('结构化拒绝：快照缺失/含空白名时不得进入可保存状态，不猜展示串', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    // 下钻到带空白标签的节点（数据集未产出权威展示名）。
    await _tapPickerRow(tester, 'country-${_FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'node-${_FakeGeoSource.tokyoId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'node-${_FakeGeoSource.blankId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection, isNotNull, reason: '草稿已确认');
    expect(state.selectedRegion, isEmpty, reason: '无权威展示快照时不得猜测展示串');
    expect(state.hasChanged, isFalse, reason: '结构上必败的草稿不进入可保存状态');

    // 「完成」不可用；即便误触也不发起保存、不写缓存。
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0, reason: '结构化本地拒绝：不发必败请求');
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(_legacySelectionKey()), isNull);
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('层级未知诚实呈现：未知辖区不冒充末级，确认不可用', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    await _tapPickerRow(tester, 'country-${_FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'node-${_FakeGeoSource.unknownWardId}');
    await tester.pumpAndSettle();

    // 未知覆盖显式标注，不渲染为「最深一级」。
    expect(find.byKey(const ValueKey('coverage-unknown')), findsOneWidget);

    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection, isNull, reason: '未知层级不可确认');
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(StorageService.to.getStringList(_legacySelectionKey()), isNull);
  });

  testWidgets('结构化失败恢复：保存失败保留草稿、留在页面、不写缓存', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return false;
      },
    );
    const previousSelection = ['中国香港 中西区', '中国香港', '中西区'];
    final scopedKey = _legacySelectionKey();
    expect(
      await StorageService.to.setList(scopedKey, previousSelection),
      isTrue,
    );
    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(
      find.byType(SetRegionPage, skipOffstage: false),
      findsOneWidget,
      reason: '失败留在当前页面',
    );
    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection, isNotNull, reason: '失败保留草稿');
    expect(state.hasChanged, isTrue);
    expect(state.geoSelection!.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);
    expect(await RegionCache.loadSelectedRegion(), isEmpty, reason: '失败不写缓存');
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(scopedKey), previousSelection);
  });

  testWidgets('结构化取消：确认草稿后直接退出，不触发保存不写缓存', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );
    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    await _popRegionRoute(tester);
    await tester.pumpAndSettle();

    expect(saveCalls, 0, reason: '取消不得触发结构化保存');
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(_legacySelectionKey()), isNull);
    expect(find.text('MorePage'), findsOneWidget);
  });

  testWidgets('切语言不改 ID：草稿稳定 ID 不变、标签重渲染、不触发保存', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));

    await _tapPickerRow(tester, 'country-${_FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'node-${_FakeGeoSource.tokyoId}');
    await tester.pumpAndSettle();

    final draftIdBefore = tester
        .widget<Text>(find.byKey(const ValueKey('draft-id')))
        .data;

    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.enUs));
    await tester.pumpAndSettle();

    // 显式映射：enUs → 'en-US'；标签按新 locale 重渲染。
    expect(source.resolvedLabelLocales, contains('en-US'));
    expect(find.text('Shibuya'), findsOneWidget, reason: '草稿标签已按 en-US 重渲染');

    // 稳定 ID 不因语言切换而改变（UX-02/AC-89）。
    final draftIdAfter = tester
        .widget<Text>(find.byKey(const ValueKey('draft-id')))
        .data;
    expect(draftIdAfter, draftIdBefore);
    expect(draftIdAfter, contains(_FakeGeoSource.tokyoId));

    // 切换后确认：selection 携带新 locale 快照，ID 仍是数据集稳定 ID。
    await _tapPickerRow(tester, 'node-${_FakeGeoSource.shibuyaId}');
    await tester.pumpAndSettle();
    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection!.pathIds, [
      'cc:JP',
      'jp:13',
      'jp:13103',
    ], reason: '语言切换不改选择身份');
    expect(state.geoSelection!.displayLocale, 'en-US');
    expect(state.selectedRegion, 'Japan Tokyo Shibuya');
    expect(saveCalls, 0, reason: '切语言本身从未触发保存，保存只由完成发起');
  });

  testWidgets('Web Geo 预览继承阿语方向，页面文案使用地区字体', (tester) async {
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.arSa));
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    const title = 'إعداد منطقة المعاينة';
    await _pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: title,
        currentValue: '',
        onSave: (_) async => false,
        canSavePreview: () => true,
      ),
      previewSource: () async => _FakeGeoSource(),
    );
    final page = tester.element(find.byType(SetRegionPage));
    final picker = tester.element(find.byType(GeoRegionPicker));
    expect(Directionality.of(page), TextDirection.rtl);
    expect(Directionality.of(picker), Directionality.of(page));

    await _drillToShibuya(tester);
    await _tapPickerRow(tester, 'confirm-selection');
    final selected = find.textContaining('شيبويا').evaluate().where((element) {
      final widget = element.widget;
      return widget is Text &&
          widget.style?.fontFamilyFallback?.contains('NotoSansArabicGeo') ==
              true;
    });
    expect(selected, isNotEmpty, reason: '选中条使用真实 Geo 字体回退');
    for (final text in [
      title,
      t.common.selectedRegion.toUpperCase(),
      t.common.buttonAccomplish,
    ]) {
      final label = tester.widget<Text>(find.text(text));
      expect(
        label.style?.fontFamilyFallback,
        containsAllInOrder(['IMBoyGeoCjk', 'NotoSansArabicGeo']),
      );
    }
  });

  testWidgets('阿语 RTL 可用性：ar-SA 显式映射，长 Unicode 名称完整渲染', (tester) async {
    final source = _FakeGeoSource();
    var saveCalls = 0;
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.arSa));
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    // 显式映射：arSa → 'ar-SA'。
    expect(source.requestedLocales, contains('ar-SA'));

    await _drillToShibuya(tester);
    // 长阿语名称完整渲染（Unicode/长名可用，不做截断猜测）。
    expect(find.textContaining('شيبويا'), findsAtLeastNWidgets(1));

    await _tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = _container(tester).read(setRegionProvider);
    expect(state.geoSelection!.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);
    expect(state.geoSelection!.displayLocale, 'ar-SA');
    expect(saveCalls, 0);
  });

  testWidgets('数据源失败：选择器错误态可重试，页面不崩溃不误保存', (tester) async {
    final source = _FakeGeoSource()..failCountryLoad = true;
    var saveCalls = 0;
    await _pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );
    await tester.pumpAndSettle();

    // 离线/加载失败显式报错，页面仍存活。
    expect(find.byKey(const ValueKey('picker-error')), findsOneWidget);
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0, reason: '无草稿不发起保存');

    // 恢复数据源后重试成功（失败恢复路径）。
    source.failCountryLoad = false;
    await tester.tap(find.byKey(const ValueKey('retry-button')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('country-${_FakeGeoSource.rootId}')),
      findsOneWidget,
    );
  });
}
