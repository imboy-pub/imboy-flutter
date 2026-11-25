// FL-04 set_region 结构化数据源域：geo_regions 选择器结构化保存/拒绝/层级
// 未知诚实呈现/失败恢复/切语言不改 ID/阿语方向与地区字体。
//
// 拆分自原 set_region_page_widget_test.dart（ratchet <800 行约束）；
// 共享 fixture 见 set_region_page_widget_support.dart。

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as picker_material;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/set_region/set_region_page.dart';
import 'package:imboy/page/personal_info/set_region/set_region_provider.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/cache/region_cache.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_region_page_widget_support.dart';

void main() {
  setUpAll(prepareWebWriter);

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

    await pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: t.common.setRegion,
        currentValue: '',
        onSave: recordSave,
        onSaveSelection: recordSave,
        canSavePreview: () => true,
      ),
      rejectLegacyProvider: true,
      previewSource: () async => FakeGeoSource(),
    );
    await drillToShibuya(tester);

    final draft = find.text('cc:JP / jp:13 / jp:13103');
    final dialog = find.byType(picker_material.AlertDialog);
    Finder dialogAction(String label) =>
        find.descendant(of: dialog, matching: find.text(label));

    expect(draft, findsOneWidget);
    await tapPickerRow(tester, 'discard-button');
    expect(tester.takeException(), isNull);
    expect(dialogAction('放弃尚未确认的选择？'), findsOneWidget);
    await tester.tap(dialogAction('继续选择'));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(draft, findsOneWidget);

    await tapPickerRow(tester, 'discard-button');
    await tester.tap(dialogAction('放弃修改'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(dialog, findsNothing);
    expect(draft, findsNothing);
    expect(
      find.byKey(const ValueKey('country-${FakeGeoSource.rootId}')),
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

    await pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async => FakeGeoSource(),
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
    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
    expect(find.text('日本 東京都 渋谷区'), findsWidgets);

    await pumpEditorHarness(
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

    await pumpEditorHarness(
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

    await pumpEditorHarness(
      tester,
      editorBuilder: editor,
      previewSource: () async => FakeGeoSource(),
    );
    expect(find.text(previousRegion), findsWidgets);
    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
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
      await pumpEditorHarness(
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
          return FakeGeoSource();
        },
        previewSource: () async {
          webLoads++;
          return FakeGeoSource();
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
    }) => pumpEditorHarness(
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
      previewSource: () async => FakeGeoSource(),
      mockPreferences: preferences,
      rejectLegacyProvider: true,
    );

    await open('A', '账号 A 的地区', preferences: legacyCache);
    expect(find.text('账号 A 的地区'), findsWidgets);
    expect(find.text(legacySelection), findsNothing);
    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
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
    final source = FakeGeoSource();
    GeoSelection? savedSelection;
    String? cacheAtSaveTime;
    var saveCalls = 0;
    await pumpGeoRegionFlow(
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

    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = regionTestContainer(tester).read(setRegionProvider);
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
    final source = FakeGeoSource();
    var saveCalls = 0;
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    // 下钻到带空白标签的节点（数据集未产出权威展示名）。
    await tapPickerRow(tester, 'country-${FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'node-${FakeGeoSource.tokyoId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'node-${FakeGeoSource.blankId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.geoSelection, isNotNull, reason: '草稿已确认');
    expect(state.selectedRegion, isEmpty, reason: '无权威展示快照时不得猜测展示串');
    expect(state.hasChanged, isFalse, reason: '结构上必败的草稿不进入可保存状态');

    // 「完成」不可用；即便误触也不发起保存、不写缓存。
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0, reason: '结构化本地拒绝：不发必败请求');
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(legacySelectionKey()), isNull);
    expect(find.byType(SetRegionPage, skipOffstage: false), findsOneWidget);
  });

  testWidgets('层级未知诚实呈现：未知辖区不冒充末级，确认不可用', (tester) async {
    final source = FakeGeoSource();
    var saveCalls = 0;
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    await tapPickerRow(tester, 'country-${FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'node-${FakeGeoSource.unknownWardId}');
    await tester.pumpAndSettle();

    // 未知覆盖显式标注，不渲染为「最深一级」。
    expect(find.byKey(const ValueKey('coverage-unknown')), findsOneWidget);

    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.geoSelection, isNull, reason: '未知层级不可确认');
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();
    expect(saveCalls, 0);
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(StorageService.to.getStringList(legacySelectionKey()), isNull);
  });

  testWidgets('结构化失败恢复：保存失败保留草稿、留在页面、不写缓存', (tester) async {
    final source = FakeGeoSource();
    var saveCalls = 0;
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return false;
      },
    );
    const previousSelection = ['中国香港 中西区', '中国香港', '中西区'];
    final scopedKey = legacySelectionKey();
    expect(
      await StorageService.to.setList(scopedKey, previousSelection),
      isTrue,
    );
    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(
      find.byType(SetRegionPage, skipOffstage: false),
      findsOneWidget,
      reason: '失败留在当前页面',
    );
    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.geoSelection, isNotNull, reason: '失败保留草稿');
    expect(state.hasChanged, isTrue);
    expect(state.geoSelection!.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);
    expect(await RegionCache.loadSelectedRegion(), isEmpty, reason: '失败不写缓存');
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(scopedKey), previousSelection);
  });

  testWidgets('结构化取消：确认草稿后直接退出，不触发保存不写缓存', (tester) async {
    final source = FakeGeoSource();
    var saveCalls = 0;
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );
    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    await popRegionRoute(tester);
    await tester.pumpAndSettle();

    expect(saveCalls, 0, reason: '取消不得触发结构化保存');
    expect(await RegionCache.loadSelectedRegion(), isEmpty);
    expect(await RegionCache.loadRegionPath(), isEmpty);
    expect(StorageService.to.getStringList(legacySelectionKey()), isNull);
    expect(find.text('MorePage'), findsOneWidget);
  });

  testWidgets('切语言不改 ID：草稿稳定 ID 不变、标签重渲染、不触发保存', (tester) async {
    final source = FakeGeoSource();
    var saveCalls = 0;
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));

    await tapPickerRow(tester, 'country-${FakeGeoSource.rootId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'node-${FakeGeoSource.tokyoId}');
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
    expect(draftIdAfter, contains(FakeGeoSource.tokyoId));

    // 切换后确认：selection 携带新 locale 快照，ID 仍是数据集稳定 ID。
    await tapPickerRow(tester, 'node-${FakeGeoSource.shibuyaId}');
    await tester.pumpAndSettle();
    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = regionTestContainer(tester).read(setRegionProvider);
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
    await pumpEditorHarness(
      tester,
      editorBuilder: () => SetRegionPage(
        title: title,
        currentValue: '',
        onSave: (_) async => false,
        canSavePreview: () => true,
      ),
      previewSource: () async => FakeGeoSource(),
    );
    final page = tester.element(find.byType(SetRegionPage));
    final picker = tester.element(find.byType(GeoRegionPicker));
    expect(Directionality.of(page), TextDirection.rtl);
    expect(Directionality.of(picker), Directionality.of(page));

    await drillToShibuya(tester);
    await tapPickerRow(tester, 'confirm-selection');
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
    final source = FakeGeoSource();
    var saveCalls = 0;
    await tester.runAsync(() => LocaleSettings.setLocale(AppLocale.arSa));
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.zhCn));
    await pumpGeoRegionFlow(
      tester,
      source: source,
      onSaveSelection: (_) async {
        saveCalls++;
        return true;
      },
    );

    // 显式映射：arSa → 'ar-SA'。
    expect(source.requestedLocales, contains('ar-SA'));

    await drillToShibuya(tester);
    // 长阿语名称完整渲染（Unicode/长名可用，不做截断猜测）。
    expect(find.textContaining('شيبويا'), findsAtLeastNWidgets(1));

    await tapPickerRow(tester, 'confirm-selection');
    await tester.pumpAndSettle();

    final state = regionTestContainer(tester).read(setRegionProvider);
    expect(state.geoSelection!.pathIds, ['cc:JP', 'jp:13', 'jp:13103']);
    expect(state.geoSelection!.displayLocale, 'ar-SA');
    expect(saveCalls, 0);
  });

  testWidgets('数据源失败：选择器错误态可重试，页面不崩溃不误保存', (tester) async {
    final source = FakeGeoSource()..failCountryLoad = true;
    var saveCalls = 0;
    await pumpGeoRegionFlow(
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
      find.byKey(const ValueKey('country-${FakeGeoSource.rootId}')),
      findsOneWidget,
    );
  });
}
