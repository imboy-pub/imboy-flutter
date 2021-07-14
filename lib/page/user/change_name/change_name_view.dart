import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'change_name_logic.dart';
import 'change_name_state.dart';

class ChangeNamePage extends StatefulWidget {
  @override
  _ChangeNamePageState createState() => _ChangeNamePageState();
}

class _ChangeNamePageState extends State<ChangeNamePage> {
  final logic = Get.find<ChangeNameLogic>();
  final ChangeNameState state = Get.find<ChangeNameLogic>().state;

  @override
    Widget build(BuildContext context) {
      return Container();
    }

  @override
  void dispose() {
    Get.delete<ChangeNameLogic>();
    super.dispose();
  }
}