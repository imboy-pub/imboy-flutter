import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cooperation_logic.dart';
import 'cooperation_state.dart';

class CooperationPage extends StatefulWidget {
  const CooperationPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _CooperationPageState createState() => _CooperationPageState();
}

class _CooperationPageState extends State<CooperationPage> {
  final CooperationLogic logic = Get.put(CooperationLogic());
  final CooperationState state = Get.find<CooperationLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  void dispose() {
    Get.delete<CooperationLogic>();
    super.dispose();
  }
}
