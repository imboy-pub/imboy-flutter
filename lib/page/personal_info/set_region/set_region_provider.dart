import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:geo_regions/geo_regions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/account_preferences.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/cache/region_cache.dart';

part 'set_region_provider.g.dart';

/// 将当前节点追加到显式父级路径，避免递归页面通过标题反推祖先。
List<String> buildRegionPath(List<String> parentPath, String title) => [
  ...parentPath,
  title,
];

/// 设置地区状态
class SetRegionState {
  final List<dynamic> regionList;
  final String selectedRegion;
  final bool hasChanged;
  final List<String> regionPath;

  /// 已确认的结构化草稿（geo_regions 选择器下钻产生，pathIds 来自
  /// pinned 数据集）。`null` 表示尚未确认结构化选择。
  final GeoSelection? geoSelection;

  const SetRegionState({
    this.regionList = const [],
    this.selectedRegion = '',
    this.hasChanged = false,
    this.regionPath = const [],
    this.geoSelection,
  });

  SetRegionState copyWith({
    List<dynamic>? regionList,
    String? selectedRegion,
    bool? hasChanged,
    List<String>? regionPath,
    GeoSelection? geoSelection,
  }) {
    return SetRegionState(
      regionList: regionList ?? this.regionList,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      hasChanged: hasChanged ?? this.hasChanged,
      regionPath: regionPath ?? this.regionPath,
      geoSelection: geoSelection ?? this.geoSelection,
    );
  }
}

/// 设置地区 Provider
@riverpod
class SetRegionNotifier extends _$SetRegionNotifier {
  String _initialValue = '';
  List<String> _initialPath = const [];
  AccountPreferences? _preferences;
  List<dynamic> _fullRegionList = [];

  @override
  SetRegionState build() {
    Future<dynamic>.delayed(Duration.zero, () async {
      await _loadRegionData();
      if (!ref.mounted) return;

      final cachedList = await RegionCache.loadRegionList();
      if (!ref.mounted) return;
      if (cachedList.isNotEmpty) {
        state = state.copyWith(regionList: cachedList);
      } else if (_fullRegionList.isNotEmpty) {
        state = state.copyWith(regionList: _fullRegionList);
      }
    });
    return const SetRegionState();
  }

  /// 以当前账号资料初始化，缓存只补齐原始路径分段。
  void initData(String currentValue, AccountPreferences preferences) {
    if (_preferences == null) {
      authSessionReader.addListener(_clearRevokedSelection);
      ref.onDispose(
        () => authSessionReader.removeListener(_clearRevokedSelection),
      );
    }
    _preferences = preferences;
    _initialValue = preferences.isCurrent ? currentValue : '';
    _initialPath =
        RegionCache.readSelectionPath(preferences, _initialValue) ??
        _initialValue
            .split(' ')
            .where((part) => part.trim().isNotEmpty)
            .toList();
    revertToInitial();
  }

  void _clearRevokedSelection() {
    if (!ref.mounted || _preferences?.isCurrent != false) return;
    _initialValue = '';
    _initialPath = const [];
    revertToInitial();
  }

  /// 加载 assets/data/region.json
  Future<void> _loadRegionData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/region.json');
      if (!ref.mounted) return;
      final List<dynamic> data = json.decode(jsonString) as List<dynamic>;
      _fullRegionList = data;
      state = state.copyWith(regionList: data);
      await RegionCache.saveRegionList(data);
    } catch (e) {
      iPrint('加载地区数据失败: $e');
    }
  }

  /// 判断某个名称是否已被选中
  bool isRegionSelected(String regionName) {
    return state.regionPath.contains(regionName);
  }

  /// 顶层搜索应用
  void applyTopSearch(String keyword) {
    final kw = keyword.trim().toLowerCase();
    if (kw.isEmpty) {
      state = state.copyWith(regionList: _fullRegionList);
      return;
    }

    final out = <dynamic>[];
    for (final item in _fullRegionList) {
      if (item is String) {
        if (item.toLowerCase().contains(kw)) out.add(item);
      } else if (item is Map) {
        final title = (item['title'] ?? '').toString();
        if (title.toLowerCase().contains(kw)) {
          out.add(item);
          continue;
        }
        // 简单深度搜索
        final children = (item['children'] ?? <dynamic>[]) as List<dynamic>;
        if (children.any(
          (c) => (c is String ? c : (c['title'] ?? ''))
              .toString()
              .toLowerCase()
              .contains(kw),
        )) {
          out.add(item);
        }
      }
    }
    state = state.copyWith(regionList: out);
  }

  /// 更新待保存的选择。缓存只在服务端保存成功后提交。
  void updateSelection(List<String> path) {
    final normalizedPath = path
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final value = normalizedPath.join(' ');
    state = state.copyWith(
      selectedRegion: value,
      regionPath: normalizedPath,
      hasChanged: value != _initialValue,
    );
  }

  /// Geo 选择器确认的结构化草稿（geo_regions 协议 §8）。
  ///
  /// [selection] 的 pathIds 来自数据集真实下钻/搜索，绝不由展示串反推；
  /// 展示串只取权威 displaySnapshot。快照缺失或含空白名时，无法构造
  /// 后端可接受的 region 展示串（协议本地拒绝语义），页面不得进入
  /// 可保存状态，也不猜测展示串。
  void updateSelectionFromGeo(GeoSelection selection) {
    final snapshot = selection.displaySnapshot;
    final complete =
        snapshot != null &&
        snapshot.isNotEmpty &&
        snapshot.every((name) => name.trim().isNotEmpty);
    if (!complete) {
      state = state.copyWith(
        geoSelection: selection,
        selectedRegion: '',
        regionPath: const [],
        hasChanged: false,
      );
      return;
    }
    final value = snapshot.join(' ');
    state = state.copyWith(
      geoSelection: selection,
      selectedRegion: value,
      regionPath: List<String>.of(snapshot),
      hasChanged: value != _initialValue,
    );
  }

  /// 服务端保存成功后，持久化地区字符串与完整路径。
  Future<void> persistSelection(
    AccountPreferences preferences,
    SetRegionState saved,
  ) => RegionCache.saveSelection(
    preferences,
    saved.selectedRegion,
    saved.regionPath,
  );

  /// 回滚到初始选择值；未提交的选择（含结构化草稿）不会污染持久化缓存。
  void revertToInitial() {
    // 直接构造而非 copyWith：结构化草稿需显式清空（copyWith 的
    // `??` 语义无法把可空字段置回 null）。
    state = SetRegionState(
      regionList: state.regionList,
      selectedRegion: _initialValue,
      hasChanged: false,
      regionPath: _initialPath,
      geoSelection: null,
    );
  }
}
