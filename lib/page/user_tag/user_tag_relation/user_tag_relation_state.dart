import 'package:get/get.dart';
import 'package:textfield_tags/textfield_tags.dart';

class UserTagRelationState {

  RxBool loaded = false.obs;

  TextfieldTagsController tagController = TextfieldTagsController();
  RxDouble distanceToField = Get.width.obs;

  // 当前朋友的标签
  RxList<String> tagItems = <String>[].obs;

  // 当前用户最近添加的标签
  RxList<String> recentTagItems = <String>[
    // "标签1", "aaaa", "标签2滴答滴答滴答滴答","ddd", "标签3端订单","标签3", "标签4","标签5", "标签6","标签7", "标签8","标签9", "标签10",
  ].obs;

  TagAddState() {
    ///Initialize variables
  }
}
