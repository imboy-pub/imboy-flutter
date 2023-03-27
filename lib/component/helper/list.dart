// import 'package:flutter/foundation.dart';

/// 使用 original 中 所有 元素创建一个 n 列的二维数组
List listTo2D(List original, int n) {
  List result = [];
  if (original.length < n) {
    result.add(original);
    return result;
  }
  while (true) {
    List li = original.sublist(0, n);
    result.add(li);
    // debugPrint("oneDimensionalToTow ${li.length}");
    original = original.sublist(n);
    if (original.length < n) {
      if (original.isNotEmpty) result.add(original);
      // debugPrint("oneDimensionalToTow ${result.toList().toString()}");
      return result;
    }
  }
}
