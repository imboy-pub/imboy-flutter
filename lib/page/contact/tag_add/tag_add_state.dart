import 'package:get/get.dart';
import 'package:textfield_tags/textfield_tags.dart';

class TagAddState {
  TextfieldTagsController tagsController = TextfieldTagsController();
  RxDouble distanceToField = Get.width.obs;

  RxList<String> tagItems = <String>[].obs;

  TagAddState() {
    ///Initialize variables
  }
}
