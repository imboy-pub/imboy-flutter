import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter/material.dart';

part 'select_region_provider.g.dart';

/// 选择地区状态
class SelectRegionState {
  final bool valueChanged;
  final String selectedVal;
  final Map<String, Map<String, dynamic>> regionSelected;

  const SelectRegionState({
    this.valueChanged = false,
    this.selectedVal = '',
    this.regionSelected = const {},
  });

  SelectRegionState copyWith({
    bool? valueChanged,
    String? selectedVal,
    Map<String, Map<String, dynamic>>? regionSelected,
  }) {
    return SelectRegionState(
      valueChanged: valueChanged ?? this.valueChanged,
      selectedVal: selectedVal ?? this.selectedVal,
      regionSelected: regionSelected ?? this.regionSelected,
    );
  }
}

/// 选择地区 Provider
@riverpod
class SelectRegionNotifier extends _$SelectRegionNotifier {
  @override
  SelectRegionState build() {
    return const SelectRegionState();
  }

  /// 更新值变化状态
  void valueOnChange(bool isChange) {
    state = state.copyWith(valueChanged: isChange);
  }

  /// 更新选中的值
  void updateSelectedVal(String value) {
    state = state.copyWith(selectedVal: value);
  }

  /// 选中title
  void regionSelectedTitle(String title) {
    final newRegionSelected = Map<String, Map<String, dynamic>>.from(
      state.regionSelected,
    );
    newRegionSelected.clear();
    newRegionSelected[title.trim()] = {
      'selected': true,
      'trailing': const Text(
        '√',
        style: TextStyle(fontSize: 20, color: Colors.green),
      ),
    };
    state = state.copyWith(regionSelected: newRegionSelected);
  }

  /// 判断地区是否被选中
  bool isRegionSelected(String title) {
    final regionData = state.regionSelected[title];
    return regionData != null && regionData['selected'] == true;
  }

  /// 判断地区是否有子节点
  bool hasChildren(dynamic model) {
    if (model is String) {
      return false;
    } else if (model is Map) {
      final children = model["children"] ?? <dynamic>[];
      return children.isNotEmpty;
    }
    return false;
  }

  /// 获取地区标题
  String getRegionTitle(dynamic model) {
    if (model is String) {
      return model;
    } else if (model is Map) {
      return model["title"] ?? "";
    }
    return "";
  }

  /// 获取地区子节点
  List<dynamic> getRegionChildren(dynamic model) {
    if (model is Map) {
      return model["children"] ?? [];
    }
    return [];
  }
}
