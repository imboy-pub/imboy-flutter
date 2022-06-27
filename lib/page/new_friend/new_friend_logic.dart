import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class NewFriendLogic extends GetxController {
  FocusNode searchF = FocusNode();
  TextEditingController searchC = TextEditingController();

  RxList<dynamic> items = [].obs;
}
