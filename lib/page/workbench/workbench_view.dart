import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'workbench_logic.dart';
import 'workbench_state.dart';

class WorkbenchPage extends StatelessWidget {
  final WorkbenchLogic logic = Get.put(WorkbenchLogic());
  final WorkbenchState state = Get.find<WorkbenchLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
