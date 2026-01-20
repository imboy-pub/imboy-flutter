import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_provider.g.dart';

/// 更新页面状态
class UpdatePageState {
  final String value;
  final bool valueChanged;

  const UpdatePageState({this.value = '', this.valueChanged = false});

  UpdatePageState copyWith({String? value, bool? valueChanged}) {
    return UpdatePageState(
      value: value ?? this.value,
      valueChanged: valueChanged ?? this.valueChanged,
    );
  }
}

/// 更新页面 Provider
@riverpod
class UpdatePageNotifier extends _$UpdatePageNotifier {
  @override
  UpdatePageState build() {
    return const UpdatePageState();
  }

  /// 更新值
  void setVal(String value) {
    state = state.copyWith(value: value);
  }

  /// 值变化处理
  void valueOnChange(String originalValue, bool isChange) {
    state = state.copyWith(valueChanged: isChange);
  }
}

/// 文本控制器 Provider
final updateTextControllerProvider = Provider<TextEditingController>((ref) {
  final controller = TextEditingController();
  ref.onDispose(() => controller.dispose());
  return controller;
});

/// 焦点节点 Provider
final updateFocusNodeProvider = Provider<FocusNode>((ref) {
  final node = FocusNode();
  ref.onDispose(() => node.dispose());
  return node;
});
