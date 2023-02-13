import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'all_label_logic.dart';
import 'all_label_state.dart';

class AllLabelPage extends StatefulWidget {
  const AllLabelPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _AllLabelPageState createState() => _AllLabelPageState();
}

class _AllLabelPageState extends State<AllLabelPage> {
  final logic = Get.find<AllLabelLogic>();
  final AllLabelState state = Get.find<AllLabelLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<AllLabelLogic>();
    super.dispose();
  }
}
