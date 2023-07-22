import 'package:get/get.dart';

class RecentlyRegisteredUserState {
  int page = 1;
  int size = 50;

  RxList peopleList = [].obs;

  Rx<String> kwd = ''.obs;

  RecentlyRegisteredUserState() {
    ///Initialize variables
  }
}
