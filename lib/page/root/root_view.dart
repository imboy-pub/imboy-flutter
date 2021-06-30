import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'root_logic.dart';
import 'root_state.dart';

class RootPage extends StatelessWidget {
  final RootLogic logic = Get.put(RootLogic());
  final RootState state = Get.find<RootLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
