// FL-04 set_region 页面 widget 测试共享 fixture/harness。
//
// 拆分自 set_region_page_widget_test.dart（file_size_ratchet <800 行约束）：
// 假 prefs registry / fixture Notifier / 语言重建壳 / 地区流程 pump 辅助 /
// FakeGeoSource（geo_regions 选择器内存数据源）下沉至此；用例按业务域
// 分布在 set_region_page_widget_test.dart 与
// set_region_page_structured_geo_test.dart。本文件不含用例。

import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart'
    as picker_l10n;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/login_account_history_service.dart';
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class RejectLoginRegistry extends InMemorySharedPreferencesStore {
  RejectLoginRegistry()
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

const regionFixture = [
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
class FixtureRegionNotifier extends SetRegionNotifier {
  @override
  SetRegionState build() => const SetRegionState(regionList: regionFixture);
}

class UnusedLegacyRegionNotifier extends SetRegionNotifier {
  @override
  SetRegionState build() =>
      throw StateError('preview used the legacy provider');
}

/// 测试根壳：镜像 run.dart:198 的语言切换重建机制。应用使用全局 `t`
/// （strings.g.dart:222，无 context 依赖），整树重建靠根壳监听
/// LocaleSettings.getLocaleStream 并把新 locale 传给 MaterialApp；
/// 测试不复刻该机制则被测页面不会随 LocaleSettings 变化重建。
class LocaleRebuildHarness extends StatefulWidget {
  const LocaleRebuildHarness({required this.child, super.key});

  final Widget child;

  @override
  State<LocaleRebuildHarness> createState() => LocaleRebuildHarnessState();
}

class LocaleRebuildHarnessState extends State<LocaleRebuildHarness> {
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
Future<void> pumpEditorHarness(
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
          setRegionProvider.overrideWith(UnusedLegacyRegionNotifier.new)
        else if (!useProductionProvider)
          setRegionProvider.overrideWith(FixtureRegionNotifier.new),
        if (previewSource != null)
          geoRegionPreviewSourceProvider.overrideWith((_) => previewSource()),
        if (androidQaSource != null)
          androidGeoQaSourceProvider.overrideWith((_) => androidQaSource()),
      ],
      child: LocaleRebuildHarness(
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

Future<void> pumpRegionFlow(
  WidgetTester tester, {
  required Future<bool> Function(String) onSave,
}) async {
  await pumpEditorHarness(
    tester,
    editorBuilder: () =>
        SetRegionPage(title: '地区', currentValue: '', onSave: onSave),
  );
  await waitForRegionData(tester);
}

Future<void> waitForRegionData(WidgetTester tester) async {
  final mainland = find.text('中国大陆');
  await tester.pump();
  expect(mainland, findsOneWidget, reason: '地区测试夹具应显示中国大陆');
}

Future<void> tapRegion(WidgetTester tester, String title) async {
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

Future<void> popRegionRoute(WidgetTester tester) async {
  // IosPageTemplate 使用 GlassBackButton，而不是 Cupertino 默认返回按钮；
  // 直接 pop 当前 Navigator，避免 WidgetTester.pageBack 的组件类型假设。
  final rootPage = find.byType(SetRegionPage, skipOffstage: false);
  Navigator.of(tester.element(rootPage)).pop();
  await tester.pumpAndSettle();
}

Future<void> selectBeijingDongcheng(WidgetTester tester) async {
  await tapRegion(tester, '中国大陆');
  await tapRegion(tester, '北京');
  await tapRegion(tester, '东城');
}

ProviderContainer regionTestContainer(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(SetRegionPage, skipOffstage: false)),
  );
}

String legacySelectionKey() => AccountPreferences.capture().owner.preferenceKey(
  RegionCache.legacySelectionPreferenceKey,
);

/// geo_regions 选择器的内存数据源：pathIds 只从这份固定数据集产生，
/// 页面/Provider 绝不反推 ID。标签表按包内 alias 规范键控（kGeoLocaleAliases）。
class FakeGeoSource implements GeoRegionDataSource {
  FakeGeoSource();

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

Future<void> pumpGeoRegionFlow(
  WidgetTester tester, {
  required FakeGeoSource source,
  required Future<bool> Function(GeoSelection selection) onSaveSelection,
}) async {
  await pumpEditorHarness(
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
Future<void> tapPickerRow(WidgetTester tester, String keyId) async {
  final finder = find.byKey(ValueKey(keyId));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> drillToShibuya(WidgetTester tester) async {
  await tapPickerRow(tester, 'country-${FakeGeoSource.rootId}');
  await tapPickerRow(tester, 'node-${FakeGeoSource.tokyoId}');
  await tapPickerRow(tester, 'node-${FakeGeoSource.shibuyaId}');
}
