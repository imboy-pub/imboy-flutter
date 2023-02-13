import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'group_select_logic.dart';
import 'group_select_state.dart';

class GroupSelectPage extends StatefulWidget {
  const GroupSelectPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _GroupSelectPageState createState() => _GroupSelectPageState();
}

class _GroupSelectPageState extends State<GroupSelectPage> {
  final logic = Get.find<GroupSelectLogic>();
  final GroupSelectState state = Get.find<GroupSelectLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<GroupSelectLogic>();
    super.dispose();
  }
}
