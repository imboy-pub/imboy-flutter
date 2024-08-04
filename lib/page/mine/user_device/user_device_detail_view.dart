import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/store/model/user_device_model.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;

import 'change_name_view.dart';
import 'user_device_logic.dart';

// ignore: must_be_immutable
class UserDeviceDetailPage extends StatelessWidget {
  int page = 1;
  int size = 1000;

  final logic = Get.find<UserDeviceLogic>();
  final state = Get.find<UserDeviceLogic>().state;

  UserDeviceModel model;

  UserDeviceDetailPage({super.key, required this.model});

  RxString deviceName = "".obs;

  void initData() async {
    deviceName.value = model.deviceName;
  }

  @override
  Widget build(BuildContext context) {
    //
    initData();
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'device_details'.tr,
      ),
      body: SingleChildScrollView(
        child: SizedBox(
          width: Get.width,
          height: Get.height,
          child: n.Column([
            LabelRow(
              label: 'device_name'.tr,
              isLine: true,
              isRight: true,
              rightW: SizedBox(
                child: Obx(() => Text(
                      deviceName.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withOpacity(0.8),
                        fontWeight: FontWeight.w400,
                      ),
                    )),
              ),
              onPressed: () {
                Get.to(
                  () => ChangeNamePage(
                      title: 'set_param'.trArgs(['device_name'.tr]),
                      value: model.deviceName,
                      field: 'input',
                      callback: (newName) async {
                        bool ok = await logic.changeName(
                          deviceId: model.deviceId,
                          name: newName,
                        );
                        if (ok) {
                          deviceName.value = newName;
                          int i = state.deviceList
                              .indexWhere((e) => e.deviceId == model.deviceId);
                          model.deviceName = newName;
                          state.deviceList.replaceRange(i, i + 1, [model]);
                        }
                        return ok;
                      }),
                  transition: Transition.rightToLeft,
                  popGesture: true, // 右滑，返回上一页
                );
              },
            ),
            LabelRow(
              label: 'device_type'.tr,
              isLine: false,
              isRight: false,
              rightW: SizedBox(
                child: Text(
                  model.showType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              onPressed: () {},
            ),
            const HorizontalLine(
              height: 4,
            ),
            LabelRow(
              label: 'last_active_time'.tr,
              isLine: false,
              isRight: false,
              rightW: SizedBox(
                child: Text(
                  Jiffy.parseFromMillisecondsSinceEpoch(model.lastActiveAtLocal)
                      .format(pattern: 'yyyy-MM-dd HH:mm:ss'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.8),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              onPressed: () {},
            ),
            n.Padding(
              top: 10,
              left: 14,
              right: 8,
              bottom: 10,
              // 当设备处于安全状态时，会自动延长登录时间以保持朋友消息的及时收发，此时会更新最近活跃时问。
              child: Text('last_active_tips'.tr),
            ),
            ButtonRow(
              margin: const EdgeInsets.only(top: 10.0, bottom: 10.0),
              text: 'delete_this_device'.tr,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              isBorder: false,
              onPressed: () async {
                // 删除后，下次在该设备登录时需要进行安全验证。
                String tips = 'delete_this_device_tips'.tr;
                n.showDialog(
                  context: Get.context!,
                  builder: (context) => n.Alert()
                    ..content = SizedBox(
                      height: 40,
                      child: Center(
                          child: Text(
                        tips,
                        style: const TextStyle(color: Colors.red),
                      )),
                    )
                    ..actions = [
                      n.Button('button_cancel'.tr.n)
                        ..style = n.NikuButtonStyle(
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                        )
                        ..onPressed = () {
                          Navigator.of(context).pop();
                        },
                      n.Button('button_delete'.tr.n)
                        ..style = n.NikuButtonStyle(
                          foregroundColor:
                              Theme.of(context).colorScheme.onSurface,
                        )
                        ..onPressed = () async {
                          var nav = Navigator.of(context);

                          bool res = await logic.deleteDevice(
                            model.deviceId,
                          );
                          if (res) {
                            state.deviceList.removeAt(
                              state.deviceList.indexWhere(
                                  (e) => e.deviceId == model.deviceId),
                            );
                            EasyLoading.showSuccess('tip_success'.tr);
                            nav.pop();
                            Get.back(times: 1);
                          } else {
                            EasyLoading.showError('tip_failed'.tr);
                          }
                        },
                    ],
                  barrierDismissible: true,
                );
              },
            ),
          ])
            ..mainAxisSize = MainAxisSize.min,
        ),
      ),
    );
  }
}
