import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'discover_logic.dart';
import 'discover_state.dart';

class DiscoverPage extends StatelessWidget {
  final DiscoverLogic logic = Get.put(DiscoverLogic());
  final DiscoverState state = Get.find<DiscoverLogic>().state;

  DiscoverPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
