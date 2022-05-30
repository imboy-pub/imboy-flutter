import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'update_logic.dart';

class UpdatePage extends StatelessWidget {
  UpdatePage(this.field, this.value, this.title);
  String field;
  String value;
  String title;
  @override
  Widget build(BuildContext context) {
    final logic = Get.put(UpdateLogic());
    final state = Get.find<UpdateLogic>().state;

    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: this.title),
      body: Container(),
    );
  }
}
