import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'welcome_logic.dart';

class WelcomePage extends StatelessWidget {
  WelcomePage({Key? key}) : super(key: key);

  final logic = Get.find<WelcomeLogic>();
  final state = Get.find<WelcomeLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
