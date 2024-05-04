import 'package:get/get.dart';

class GroupListState {
  GroupListState() {
    ///Initialize variables
  }

  int size = 1000;
  int page = 1;

  bool isSearch = false;

  RxList groupList = [].obs;

}
