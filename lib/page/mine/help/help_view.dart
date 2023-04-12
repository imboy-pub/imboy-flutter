import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'help_logic.dart';
import 'help_state.dart';

class HelpPage extends StatelessWidget {
  final HelpLogic logic = Get.put(HelpLogic());
  final HelpState state = Get.find<HelpLogic>().state;

  HelpPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
