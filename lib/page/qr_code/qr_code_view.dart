import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'qr_code_logic.dart';
import 'qr_code_state.dart';

class QrCodePage extends StatefulWidget {
  @override
  _QrCodePageState createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final logic = Get.find<QrCodeLogic>();
  final QrCodeState state = Get.find<QrCodeLogic>().state;

  @override
    Widget build(BuildContext context) {
      return Container();
    }

  @override
  void dispose() {
    Get.delete<QrCodeLogic>();
    super.dispose();
  }
}