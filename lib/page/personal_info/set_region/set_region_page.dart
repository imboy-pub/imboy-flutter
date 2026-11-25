import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:dio/dio.dart' show Options;
import 'package:geo_regions/geo_regions.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// geo_regions 选择器（pinned 包）基于官方 flutter/material 构建，而本 app
// UI 层使用 material_ui fork——两者的 Material / MaterialLocalizations 是
// 不同运行时类型。以下 alias 导入仅供嵌入点为选择器提供真实 Material
// 祖先与本地化代理，不用于页面自身 UI（页面 UI 仍走 cupertino/material_ui）。
// 官方库的弃用提示指向 fork 替换，但 fork 类型与 pinned geo_regions
// 选择器互不兼容，此处必须用官方类型，定向豁免。
// ignore: deprecated_member_use
import 'package:flutter/material.dart' as picker_material;
// ignore: deprecated_member_use
import 'package:flutter_localizations/flutter_localizations.dart'
    as picker_l10n;

import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_request_policy.dart'
    show httpNoAutoRetry, httpRequestGuard, webSelfRegionSelectionPath;
import 'package:imboy/config/const.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/geo_regions/geo_regions_host.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';
import 'package:imboy/store/service/user_profile_service.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'set_region_provider.dart';

part 'set_region_sub_page.dart';

/// 设置地区页面 - 像素级对齐 iOS 17 Premium 风格
class SetRegionPage extends ConsumerStatefulWidget {
  final String title;
  final String currentValue;
  final Future<bool> Function(String) onSave;

  /// geo_regions 选择器数据源（pinned 数据集经 [GeoRegionDataSource]
  /// 注入）。提供后页面进入结构化模式：以数据集真实 pathIds 构造
  /// GeoSelection，保存走结构化身份协议（regionSelection），legacy
  /// `region` 字符串链路保持不变。
  final GeoRegionDataSource? geoDataSource;

  /// 结构化保存入口；缺省为 [UserProfileService.updateRegionSelection]。
  /// 仅测试注入使用，生产走默认实现。
  final Future<bool> Function(GeoSelection selection)? onSaveSelection;

  /// A read-only self profile supplies a fence for the session that opened
  /// the preview. This mode never permits a legacy save.
  final bool Function()? canSavePreview;

  final bool androidGeoQa;

  const SetRegionPage({
    super.key,
    required this.title,
    required this.currentValue,
    required this.onSave,
    this.geoDataSource,
    this.onSaveSelection,
    this.canSavePreview,
    this.androidGeoQa = false,
  });

  @override
  ConsumerState<SetRegionPage> createState() => _SetRegionPageState();
}

class _SetRegionPageState extends ConsumerState<SetRegionPage> {
  late final AccountPreferences _preferences;
  AuthSessionScope? _previewAuth;
  bool _previewRevoked = false;
  final TextEditingController _searchC = TextEditingController();
  Timer? _debounce;
  bool _isSaving = false;
  bool _previewSaveBlocked = false;
  GeoSelection? _previewSelection;
  UserProfileSessionSnapshot? _androidQaOwner;

  static final _previewFonts = [
    kAppFontFamilyFallback.first,
    'IMBoyGeoCjk',
    'NotoSansArabicGeo',
    ...kAppFontFamilyFallback.skip(1),
  ];

  bool get _accountScopedPreview =>
      widget.androidGeoQa || widget.canSavePreview != null;

  bool get _previewAuthCurrent {
    final owner = _previewAuth;
    return !_previewRevoked &&
        owner != null &&
        authSessionReader.isCurrent(owner);
  }

  void _onPreviewAuthChanged() {
    if (!mounted || _previewRevoked || _previewAuthCurrent) return;
    setState(() {
      _previewRevoked = true;
      _previewSelection = null;
    });
  }

  bool _canSaveAndroidQa(String displayedUid) {
    if (!mounted || !_previewAuthCurrent || _androidQaOwner == null) {
      return false;
    }
    final repo = ref.read(userRepoProvider);
    final current = UserProfileService.readSessionSnapshot();
    return canOpenSelfGeoPreview(
      owner: _androidQaOwner,
      current: current,
      displayedUid: displayedUid,
      sessionReady: repo.isLoggedIn && !repo.isAuthTransitioning,
      previewConfigured: androidGeoQaEndpointAllowed(
        environment: current.environment,
        endpoint: current.endpoint,
      ),
    );
  }

  void _confirmGeoSelection(GeoSelection selection) {
    if (!_accountScopedPreview) {
      ref.read(setRegionProvider.notifier).updateSelectionFromGeo(selection);
      return;
    }
    if (!_previewAuthCurrent || widget.canSavePreview?.call() == false) {
      return;
    }
    final normalized = UserProfileService.normalizeRegionSelectionValue(
      selection,
      serverCanonicalizesDisplay: true,
    );
    setState(() => _previewSelection = normalized?.$2);
  }

  void _resetSelection() {
    if (_accountScopedPreview) {
      setState(() => _previewSelection = null);
    } else {
      ref.read(setRegionProvider.notifier).revertToInitial();
    }
  }

  Future<void> _saveAndExit(String value) =>
      _runSave(() => widget.onSave(value));

  /// 结构化保存链：只提交已确认的结构化草稿（pathIds 来自数据集），
  /// 无草稿不发起保存。默认接 UserProfileService.updateRegionSelection
  /// （结构化身份协议），注入入口仅供测试。
  Future<void> _saveSelectionAndExit() {
    final selection = _accountScopedPreview
        ? _previewSelection
        : ref.read(setRegionProvider).geoSelection;
    if (selection == null) return Future<void>.value();
    final ownerChanged = widget.androidGeoQa
        ? !_canSaveAndroidQa(ref.read(currentUserProvider)?.uid ?? '')
        : _accountScopedPreview &&
              (!_previewAuthCurrent || widget.canSavePreview?.call() != true);
    if (ownerChanged) {
      setState(() {
        _previewSelection = null;
        _previewSaveBlocked = true;
      });
      return Future<void>.value();
    }
    final injectedSave = widget.onSaveSelection;
    if (injectedSave != null) {
      return _runSave(() => injectedSave(selection));
    }
    if (widget.androidGeoQa) {
      return _runSave(() => _saveAndroidGeoQa(selection));
    }
    if (widget.geoDataSource != null) {
      return _runSave(
        () => UserProfileService.updateRegionSelection(selection),
      );
    }
    try {
      requireLocalGeoPreviewBackend();
    } on GeoConfigurationError {
      setState(() => _previewSaveBlocked = true);
      return Future<void>.value();
    }
    return _runSave(
      () => UserProfileService.updateRegionSelection(
        selection,
        requireAuthoritativeRegion: true,
        httpPut: (data) => HttpClient.client.post(
          webSelfRegionSelectionPath,
          data: data,
          options: Options(followRedirects: false),
        ),
      ),
    );
  }

  Future<bool> _saveAndroidGeoQa(GeoSelection selection) async {
    void requireCurrent() {
      requireAndroidGeoQaBackend();
      if (!mounted ||
          !_canSaveAndroidQa(ref.read(currentUserProvider)?.uid ?? '')) {
        throw const GeoConfigurationError('Android Geo QA session changed');
      }
    }

    final source = ref.read(androidGeoQaSourceProvider).asData?.value;
    final index = source is GeoRepositoryDataSource
        ? source.repository.index
        : null;
    if (index == null) return false;

    final GeoSelection sourceSelection;
    try {
      requireCurrent();
      sourceSelection = androidGeoQaSourceSelection(selection, index);
    } on GeoException {
      if (mounted) setState(() => _previewSaveBlocked = true);
      return false;
    }

    return UserProfileService.updateRegionSelection(
      sourceSelection,
      httpPut: (data) => HttpClient.client.put(
        API.userUpdate,
        data: data,
        options: Options(
          followRedirects: false,
          extra: {httpRequestGuard: requireCurrent, httpNoAutoRetry: true},
        ),
      ),
    );
  }

  /// 保存-提交-导航统一链：服务端保存成功后才提交地区缓存并从任意
  /// 递归层级退出；失败保留草稿、留在当前页面、不写缓存。
  Future<void> _runSave(Future<bool> Function() step) async {
    if (_isSaving || !_preferences.isCurrent) return;
    final draft = _accountScopedPreview ? null : ref.read(setRegionProvider);
    setState(() => _isSaving = true);
    try {
      final saved = await step();
      if (!saved || !_preferences.isCurrent) return;

      // Preview persists through the account-fenced profile service.
      if (draft != null) {
        // 只有服务端保存成功后才提交地区缓存，失败时保留旧缓存。
        try {
          await ref
              .read(setRegionProvider.notifier)
              .persistSelection(_preferences, draft);
        } catch (error) {
          // 服务端已成功，缓存异常不能把已保存的数据伪装成保存失败。
          debugPrint('保存地区缓存失败: $error');
        }
      }
      if (!_preferences.isCurrent || !mounted) return;

      // 从任意递归层级统一退出整个地区编辑流程，回到调用方（MorePage）。
      final navigator = Navigator.of(context);
      final rootRoute = ModalRoute.of(context);
      if (rootRoute == null) return;
      navigator.popUntil((route) => identical(route, rootRoute));
      if (rootRoute.isActive) navigator.pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _preferences = AccountPreferences.capture(isActive: () => mounted);
    if (widget.androidGeoQa) {
      final displayedUid = ref.read(currentUserProvider)?.uid ?? '';
      if (displayedUid.isNotEmpty) {
        final current = UserProfileService.readSessionSnapshot();
        if (current.uid == displayedUid) _androidQaOwner = current;
      }
    }
    if (_accountScopedPreview) {
      _previewAuth = authSessionReader.current;
      authSessionReader.addListener(_onPreviewAuthChanged);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(setRegionProvider.notifier)
            .initData(widget.currentValue, _preferences);
      }
    });
    _searchC.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    if (_previewAuth != null) {
      authSessionReader.removeListener(_onPreviewAuthChanged);
    }
    _debounce?.cancel();
    _searchC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(setRegionProvider.notifier).applyTopSearch(_searchC.text);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canUsePreview = widget.androidGeoQa
        ? _canSaveAndroidQa(ref.watch(currentUserProvider)?.uid ?? '')
        : _previewAuthCurrent && widget.canSavePreview?.call() == true;
    final hidePreviewSelection = _accountScopedPreview && !canUsePreview;
    if (hidePreviewSelection) _previewSelection = null;
    final previewSelection = _previewSelection;
    final previewPath = previewSelection?.displaySnapshot;
    final state = _accountScopedPreview
        ? SetRegionState(
            selectedRegion: hidePreviewSelection
                ? ''
                : previewPath?.join(' ') ?? widget.currentValue,
            regionPath: previewPath ?? const [],
            hasChanged: previewSelection != null,
            geoSelection: previewSelection,
          )
        : ref.watch(setRegionProvider);
    final brightness = Theme.of(context).brightness;
    final previewFonts = _accountScopedPreview ? _previewFonts : null;
    final selectedPath = state.regionPath;
    final preview =
        _accountScopedPreview && widget.geoDataSource == null && canUsePreview
        ? ref.watch(
            widget.androidGeoQa
                ? androidGeoQaSourceProvider
                : geoRegionPreviewSourceProvider,
          )
        : null;
    final geoSource = hidePreviewSelection
        ? null
        : widget.geoDataSource ?? preview?.asData?.value;
    final previewBlocked =
        _previewSaveBlocked ||
        (preview != null && (preview.isLoading || preview.hasError)) ||
        (_accountScopedPreview && (geoSource == null || !canUsePreview));
    final canSave =
        !previewBlocked &&
        !_isSaving &&
        _preferences.isCurrent &&
        state.hasChanged &&
        (geoSource == null || state.geoSelection != null);

    return IosPageTemplate(
      title: widget.title,
      middle: previewFonts == null
          ? null
          : Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context
                  .textStyle(
                    FontSizeType.body,
                    fontWeight: FontWeight.w600,
                    color: brightness == Brightness.dark
                        ? AppColors.darkTextPrimary
                        : AppColors.lightTextPrimary,
                  )
                  .copyWith(
                    letterSpacing: -0.4,
                    fontFamilyFallback: previewFonts,
                  ),
            ),
      useLargeTitle: false,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: canSave
              ? (geoSource != null
                    ? _saveSelectionAndExit
                    : () => _saveAndExit(state.selectedRegion))
              : null,
          child: Text(
            t.common.buttonAccomplish,
            style: TextStyle(
              fontFamilyFallback: previewFonts,
              fontWeight: canSave ? FontWeight.w600 : FontWeight.w400,
              color: canSave
                  ? AppColors.getIosBlue(brightness)
                  : AppColors.iosGray,
            ),
          ),
        ),
      ],
      slivers: [
        if (!hidePreviewSelection) ...[
          SliverToBoxAdapter(
            child: _SelectionLevelHint(
              region: state.selectedRegion,
              level: selectedPath.length,
              fontFamilyFallback: previewFonts,
            ),
          ),

          // 当前选择回显 Section - 增强视觉提示
          SliverToBoxAdapter(
            child: ImBoySettingsSection(
              header: Text(
                t.common.selectedRegion.toUpperCase(),
                style: previewFonts == null
                    ? null
                    : TextStyle(fontFamilyFallback: previewFonts),
              ),
              children: [
                ImBoySettingsTile(
                  title: Text(
                    state.selectedRegion.isEmpty
                        ? t.main.pleaseSelect
                        : state.selectedRegion,
                    style: TextStyle(
                      fontFamilyFallback: previewFonts,
                      color: state.selectedRegion.isEmpty
                          ? AppColors.iosGray
                          : AppColors.primary,
                      fontWeight: state.selectedRegion.isEmpty
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  trailing: state.hasChanged
                      ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _resetSelection,
                          child: Icon(
                            CupertinoIcons.refresh,
                            size: 20,
                            semanticLabel: t.common.reset,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],

        // 结构化模式：geo_regions 选择器承载下钻/搜索/确认，
        // 页面只负责保存事务、缓存与导航（PROTOCOL §8）。
        // 选择器内部是官方 flutter/material 控件，嵌入点需提供真实
        // Material 祖先与 MaterialLocalizations（fork 类型互不兼容）；
        // transparency 材质不改变 iOS 页面观感。expandBody:false 使
        // 选择器 shrink-wrap 进宿主 CustomScrollView（包内嵌入约定）。
        if (previewBlocked)
          SliverToBoxAdapter(
            child: preview?.isLoading == true
                ? Center(
                    child: Semantics(
                      label: t.common.loading,
                      child: const CupertinoActivityIndicator(),
                    ),
                  )
                : NoDataView(text: '${widget.title} · ${t.common.error}'),
          )
        else if (geoSource != null)
          SliverToBoxAdapter(
            child: picker_material.Localizations(
              locale: LocaleSettings.currentLocale.flutterLocale,
              delegates: const [
                // fork 的 GlobalMaterialLocalizations 与官方 MaterialLocalizations
                // 类型不兼容，选择器需要官方类型，定向豁免弃用提示。
                // ignore: deprecated_member_use
                picker_l10n.GlobalMaterialLocalizations.delegate,
                picker_material.DefaultWidgetsLocalizations.delegate,
              ],
              child: _withPreviewTheme(
                context,
                picker_material.Material(
                  type: picker_material.MaterialType.transparency,
                  child: GeoRegionPicker(
                    dataSource: geoSource,
                    displayLocale: _geoDisplayLocale(),
                    policy: GeoSelectionPolicy.requireLeafWithinDeclared,
                    onConfirmed: _confirmGeoSelection,
                    expandBody: false,
                  ),
                ),
              ),
            ),
          )
        else ...[
          // 搜索栏
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: CupertinoSearchTextField(
                controller: _searchC,
                placeholder: t.common.regionSearchHint,
              ),
            ),
          ),

          // 地区列表 Section
          if (state.regionList.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: NoDataView(text: t.common.searchNoResults),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 40),
              sliver: SliverToBoxAdapter(
                child: ImBoySettingsSection(
                  header: Text(t.account.region.toUpperCase()),
                  children: state.regionList.map((region) {
                    String title = '';
                    List<dynamic> children = [];
                    if (region is String) {
                      title = region;
                    } else if (region is Map) {
                      title = region['title'] as String? ?? '';
                      children = region['children'] as List<dynamic>? ?? [];
                    }

                    final hasChildren = children.isNotEmpty;
                    final isSelected = selectedPath.contains(title);

                    return Semantics(
                      selected: !hasChildren && isSelected,
                      child: ImBoySettingsTile(
                        title: Text(
                          title,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        trailing: hasChildren
                            ? const CupertinoListTileChevron()
                            : (isSelected
                                  ? Icon(
                                      CupertinoIcons.check_mark,
                                      color: AppColors.getIosBlue(brightness),
                                      size: 18,
                                    )
                                  : const SizedBox.shrink()),
                        onTap: () => _handleSelection(context, title, children),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _withPreviewTheme(BuildContext context, Widget child) {
    if (!_accountScopedPreview) return child;
    final theme = picker_material.Theme.of(context);
    // The official Localizations wrapper installs its own Widgets delegate.
    // Keep the host direction inside that wrapper for the actual picker.
    return Directionality(
      textDirection: Directionality.of(context),
      child: picker_material.Theme(
        data: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamilyFallback: _previewFonts),
          primaryTextTheme: theme.primaryTextTheme.apply(
            fontFamilyFallback: _previewFonts,
          ),
        ),
        child: child,
      ),
    );
  }

  /// 当前 slang locale 到 geo_regions 选择器 displayLocale 的显式映射
  /// （locale 映射不隐式猜测：脚本缺省用语言-地区拼写）。
  String _geoDisplayLocale() {
    final locale = LocaleSettings.currentLocale;
    final script = locale.scriptCode;
    if (script != null && script.isNotEmpty) {
      return '${locale.languageCode}-$script';
    }
    final country = locale.countryCode;
    if (country == null || country.isEmpty) {
      return locale.languageCode;
    }
    return '${locale.languageCode}-$country';
  }

  void _handleSelection(
    BuildContext context,
    String title,
    List<dynamic> children,
  ) {
    if (children.isNotEmpty) {
      Navigator.push(
        context,
        CupertinoPageRoute<dynamic>(
          builder: (_) => _SubRegionPage(
            title: title,
            children: children,
            parentPath: [title],
            onSaveAndExit: _saveAndExit,
          ),
        ),
      );
    } else {
      // 叶子节点：构建完整路径并更新
      ref
          .read(setRegionProvider.notifier)
          .updateSelection(buildRegionPath(const [], title));
    }
  }
}

bool canOpenSelfGeoPreview({
  required UserProfileSessionSnapshot? owner,
  required UserProfileSessionSnapshot current,
  required String displayedUid,
  required bool sessionReady,
  required bool previewConfigured,
}) =>
    sessionReady &&
    previewConfigured &&
    owner != null &&
    owner.uid.isNotEmpty &&
    owner.uid == displayedUid &&
    owner == current;
