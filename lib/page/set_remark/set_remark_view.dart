import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'set_remark_logic.dart';
import 'set_remark_state.dart';

class SetRemarkPage extends StatefulWidget {
  @override
  _SetRemarkPageState createState() => _SetRemarkPageState();
}

class _SetRemarkPageState extends State<SetRemarkPage> {
  final logic = Get.find<SetRemarkLogic>();
  final SetRemarkState state = Get.find<SetRemarkLogic>().state;

  @override
    Widget build(BuildContext context) {
      return Container();
    }

  @override
  void dispose() {
    Get.delete<SetRemarkLogic>();
    super.dispose();
  }
}