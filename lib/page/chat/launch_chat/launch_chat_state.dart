import 'package:get/get.dart';
import 'package:imboy/store/model/contact_model.dart';

class LaunchChatState {
  LaunchChatState() {
    ///Initialize variables
  }

  RxBool valueChanged = false.obs;
  RxList<ContactModel> items = RxList<ContactModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;
}
