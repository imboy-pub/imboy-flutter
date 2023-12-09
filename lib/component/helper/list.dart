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

/// 计算两个list是否包含相同的类容；
/// 1 两个null也是不相同的；
/// 2 两个list元素相同，但是顺序不同，也是相同的list
bool listDiff(List<dynamic>? a, List<dynamic>? b) {
  if (a == null || b == null) {
    return true;
  }
  int count = 0;
  for (var i in a) {
    if (b.contains(i)) {
      count += 1;
    }
  }
  // debugPrint("tag_add_view_tagsController_listDiff ${a.length}, ${b.length}, $count");
  return a.length == b.length && a.length == count ? false : true;
}
