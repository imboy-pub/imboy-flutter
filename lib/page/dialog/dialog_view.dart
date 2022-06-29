import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'dialog_logic.dart';
import 'dialog_state.dart';

class DialogPage extends StatelessWidget {
  final DialogLogic logic = Get.put(DialogLogic());
  final DialogState state = Get.find<DialogLogic>().state;

  DialogPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
