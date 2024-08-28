import 'package:get/get.dart';
import 'package:imboy/store/model/group_model.dart';

class PeopleInfoMoreState {
  RxString sign = "".obs;
  RxString sourcePrefix = "".obs;
  RxString source = "".obs;
  RxInt groupCount = 0.obs;
  RxList<GroupModel> sameGroupList = <GroupModel>[].obs;

  PeopleInfoMoreState() {
    ///Initialize variables
  }
}
