import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'logic.dart';
import 'state.dart';

class MinePage extends StatelessWidget {
  final logic = Get.find<MineLogic>();
  final MineState state = Get.find<MineLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
