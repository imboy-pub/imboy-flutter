import 'package:get/get.dart';

class PeopleInfoState {
  // late Rx<ContactModel> people;
  RxString nickname = "".obs;
  RxString avatar = "".obs;
  RxString account = "".obs;
  RxString region = "".obs;
  RxString sign = "".obs;
  RxString source = "".obs;
  RxString title = "".obs;
  RxInt gender = 0.obs;
  RxString remark = "".obs;
  RxString tag = "".obs;
  RxInt isFriend = 0.obs;
  RxInt isFrom = 0.obs;

  PeopleInfoState() {
    ///Initialize variables
  }
}
