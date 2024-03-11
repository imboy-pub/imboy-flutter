import 'package:get/get.dart';

class DarkModelState {
  var switchValue = false.obs;

  /// 2 普通模式选择 3 深色模式选择
  var selectIndex = 2.obs;

  DarkModelState() {
    ///Initialize variables
  }
}
