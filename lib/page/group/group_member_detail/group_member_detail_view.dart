import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'group_member_detail_logic.dart';
import 'group_member_detail_state.dart';

class GroupMemberDetailPage extends StatefulWidget {
  // final bool isSelf;
  final String id;

  const GroupMemberDetailPage(this.id, {super.key});

  @override
  // ignore: library_private_types_in_public_api
  _GroupMemberDetailPageState createState() => _GroupMemberDetailPageState();
}

class _GroupMemberDetailPageState extends State<GroupMemberDetailPage> {
  final logic = Get.find<GroupMemberDetailLogic>();
  final GroupMemberDetailState state = Get.find<GroupMemberDetailLogic>().state;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: PageAppBar(title: '等待编写'),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupMemberDetailLogic>();
    super.dispose();
  }
}
