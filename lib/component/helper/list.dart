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
