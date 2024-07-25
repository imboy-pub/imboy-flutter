import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/numeric_keypad.dart';
import 'package:imboy/config/theme.dart';

import 'face_to_face_confirm_view.dart';
import 'face_to_face_logic.dart';

class FaceToFacePage extends StatelessWidget {
  final logic = Get.put(FaceToFaceLogic());
  final state = Get.find<FaceToFaceLogic>().state;

  FaceToFacePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBgColor,
      appBar: NavAppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, size: 24, color: Colors.white),
          onPressed: () {
            NavigatorState nav = Navigator.of(context);
            nav.pop();
          },
        ),
        // title: 'create_group_f2f'.tr,
        titleWidget: Text(
          'create_group_f2f'.tr,
          style: AppStyle.navAppBarTitleStyle,
        ),
        backgroundColor: darkBgColor,
      ),
      // backgroundColor: Get.isDarkMode ? darkBgColor : lightBgColor,
      body: n.Column([
        SizedBox(height: 20, width: MediaQuery.sizeOf(context).width),
        n.Row([
          Expanded(
            child: n.Padding(
              left: 48,
              right: 48,
              child: Text(
                // 'Enter the same four numbers as your friends to enter the same group chat',
                // '和身边的朋友输入同样的四个数字，进入同一个群聊',
                'create_group_f2f_tips'.tr,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ])
          // 内容居中
          ..mainAxisAlignment = MainAxisAlignment.center,
        SizedBox(height: 20, width: MediaQuery.sizeOf(context).width),
        Obx(() {
          return _buildNumberWidget(state.resultData.value.length);
        }),
        n.Row([
          Expanded(
            child: n.Padding(
              left: 20,
              right: 10,
              child: Obx(
                () => Text(state.errorInfo.value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    )),
              ),
            ),
          ),
        ])
          // 内容居中
          ..mainAxisAlignment = MainAxisAlignment.center,
        SizedBox(height: 20, width: MediaQuery.sizeOf(context).width),
        const Spacer(),
        NumericKeypad(
          controller: state.textEditingController,
          onChanged: (value) async {
            state.resultData.value = value;
            iPrint("_textEditingController value $value");
            if (value.length == 4) {
              EasyLoading.show(status: '');
              Map<String, dynamic> res = await logic.faceToFace(value);
              state.errorInfo.value = res['error'] ?? '';

              String gid = res['gid'] ?? '';
              // await Future.delayed(const Duration(seconds: 1));
              EasyLoading.dismiss();
              state.textEditingController.clearText();
              state.resultData.value = '';
              if (gid.isNotEmpty) {
                Get.to(
                  () => FaceToFaceConfirmPage(
                      code: value,
                      gid: gid,
                      memberList: res['memberList'] ?? []),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              }
              Timer(const Duration(seconds: 3), () {
                EasyLoading.dismiss();
              });
              // 接口校验
            }
          },
        ),
      ]),
    );
  }

  Widget _buildNumberWidget(int length) {
    return SizedBox(
      height: 47,
      width: 188,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemExtent: 47,
        itemBuilder: (BuildContext context, int index) {
          bool showPoint = index < length;
          Widget showVal = showPoint
              ? Text(
                  state.resultData.value[index],
                  style: const TextStyle(color: Colors.green, fontSize: 40),
                )
              : const Space(
                  height: 47,
                  width: 47,
                );
          return _buildNumberItemWidget(
            length,
            index,
            showPoint,
            showVal,
          );
        },
      ),
    );
  }

  Widget _buildNumberItemWidget(
    int length,
    int index,
    bool showPoint,
    Widget showVal,
  ) {
    iPrint("_buildNumberItemWidget length $length");
    return Container(
      height: 47,
      width: 47,
      alignment: Alignment.center,
      child: showPoint
          ? showVal
          : Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
    );
  }
}
