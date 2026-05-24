import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/cache/region_cache.dart';

part 'set_region_provider.g.dart';

/// 设置地区状态
class SetRegionState {
  final List<dynamic> regionList;
  final String selectedRegion;
  final bool hasChanged;
  final List<String> regionPath;

  const SetRegionState({
    this.regionList = const [],
    this.selectedRegion = '',
    this.hasChanged = false,
    this.regionPath = const [],
  });

  SetRegionState copyWith({
    List<dynamic>? regionList,
    String? selectedRegion,
    bool? hasChanged,
    List<String>? regionPath,
  }) {
    return SetRegionState(
      regionList: regionList ?? this.regionList,
      selectedRegion: selectedRegion ?? this.selectedRegion,
      hasChanged: hasChanged ?? this.hasChanged,
      regionPath: regionPath ?? this.regionPath,
    );
  }
}

/// 设置地区 Provider
@riverpod
class SetRegionNotifier extends _$SetRegionNotifier {
  String _initialValue = '';
  List<dynamic> _fullRegionList = [];

  @override
  SetRegionState build() {
    Future<dynamic>.delayed(Duration.zero, () async {
      await _loadRegionData();
      if (!ref.mounted) return;

      final cachedSelected = await RegionCache.loadSelectedRegion();
      if (!ref.mounted) return;
      if (cachedSelected.isNotEmpty) {
        initData(cachedSelected);
      }

      final cachedPath = await RegionCache.loadRegionPath();
      if (!ref.mounted) return;
      if (cachedPath.isNotEmpty) {
        state = state.copyWith(regionPath: cachedPath);
      }

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

  /// 初始化数据
  void initData(String currentValue) {
    _initialValue = currentValue;
    state = state.copyWith(selectedRegion: currentValue, hasChanged: false);

    if (state.selectedRegion.isNotEmpty) {
      final path = state.selectedRegion
          .split(' ')
          .where((e) => e.trim().isNotEmpty)
          .toList();
      state = state.copyWith(regionPath: path);
    } else {
      state = state.copyWith(regionPath: []);
    }
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

  /// 更新最终选择
  void updateSelection(List<String> path) {
    state = state.copyWith(
      selectedRegion: path.join(' '),
      regionPath: path,
      hasChanged: path.join(' ') != _initialValue,
    );
    RegionCache.saveSelectedRegion(path.join(' '));
    RegionCache.saveRegionPath(path);
  }

  /// 回滚到初始选择值
  void revertToInitial() {
    state = state.copyWith(selectedRegion: _initialValue, hasChanged: false);
    final initialPath = _initialValue
        .split(' ')
        .where((e) => e.trim().isNotEmpty)
        .toList();
    state = state.copyWith(regionPath: initialPath);
    RegionCache.saveSelectedRegion(_initialValue);
    RegionCache.saveRegionPath(initialPath);
  }
}
