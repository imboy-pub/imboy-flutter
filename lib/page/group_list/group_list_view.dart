import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'group_list_logic.dart';
import 'group_list_state.dart';

class GroupListPage extends StatefulWidget {
  const GroupListPage({Key? key}) : super(key: key);

  @override
  _GroupListPageState createState() => _GroupListPageState();
}

class _GroupListPageState extends State<GroupListPage> {
  final logic = Get.put(GroupListLogic());
  final GroupListState state = Get.find<GroupListLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<GroupListLogic>();
    super.dispose();
  }
}
