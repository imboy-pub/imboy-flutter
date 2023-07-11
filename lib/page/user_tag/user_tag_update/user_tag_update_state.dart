import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class UserTagUpdateState {
  FocusNode inputFocusNode = FocusNode();
  TextEditingController textController = TextEditingController();
  RxBool valueChanged = false.obs;

  UserTagUpdateState() {
    ///Initialize variables
  }
}
