// 电话号码输入组件 - 非 IO 平台存根
//
// 此文件是条件导入的存根，用于不支持 dart:io 的平台（如 Web）
// 实际的 MobilePhoneInputWidget 不会在这些平台使用

library;

import 'package:flutter/material.dart';

/// 占位符组件（实际不会被调用）
class MobilePhoneInputWidget extends StatelessWidget {
  final String initialValue;
  final Function(String) onInputChanged;
  final String? hintText;
  final InputDecoration? decoration;

  const MobilePhoneInputWidget({
    super.key,
    required this.initialValue,
    required this.onInputChanged,
    this.hintText,
    this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    // 这个实现不应该被调用，因为 Web 平台使用 _WebPhoneInputWidget
    return const SizedBox.shrink();
  }
}
