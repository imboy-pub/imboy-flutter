import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'mine_logic.dart';
import 'mine_state.dart';

class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());
  final MineState state = Get.find<MineLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
