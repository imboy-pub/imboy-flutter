import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'welcome_logic.dart';

class WelcomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final logic = Get.find<WelcomeLogic>();
    final state = Get.find<WelcomeLogic>().state;

    return Container();
  }
}
