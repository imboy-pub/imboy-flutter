import 'package:get/get.dart';

class RecentlyRegisteredUserState {
  int page = 1;
  int size = 20;
  int limit = 90;
  RxList peopleList = [].obs;

  RecentlyRegisteredUserState() {
    ///Initialize variables
  }
}
