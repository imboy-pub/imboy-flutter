import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/line.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/user_device_model.dart';

import 'user_device_detail_view.dart';
import 'user_device_logic.dart';

// ignore: must_be_immutable
class UserDevicePage extends StatelessWidget {
  int page = 1;
  int size = 1000;

  final logic = Get.put(UserDeviceLogic());
  final state = Get.find<UserDeviceLogic>().state;
  RxString currentDid = "".obs;

  UserDevicePage({super.key});

  void initData() async {
    currentDid.value = deviceId;
    var list = await logic.page(page: page, size: size);
    state.deviceList.value = list;
  }

  @override
  Widget build(BuildContext context) {
    //
    initData();
    return Scaffold(
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: 'login_device_management'.tr,
        // rightDMActions: [
        //   TextButton(
        //     onPressed: () {
        //       // Get.to(()=>
        //       //   AddFriendPage(),
        //       //   transition: Transition.rightToLeft,
        //       //   popGesture: true, // 右滑，返回上一页
        //       // );
        //     },
        //     child: Text(
        //       'edit'.tr,
        //     ),
        //   )
        // ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: Theme.of(context).colorScheme.surface,
          child: n.Column([
            n.Column([
              Container(
                width: Get.width,
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.only(
                  top: 10.0,
                  left: 15,
                  right: 10,
                  bottom: 20,
                ),
                child: Text(
                  'login_device_management_tips'.tr,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            ], mainAxisAlignment: MainAxisAlignment.spaceEvenly),
            Expanded(
              child: n.Padding(
                left: 15,
                right: 10,
                child: Obx(() {
                  return state.deviceList.isEmpty
                      ? NoDataView(text: 'no_data'.tr)
                      : ListView.builder(
                          itemCount: state.deviceList.length,
                          itemBuilder: (BuildContext context, int index) {
                            UserDeviceModel model = state.deviceList[index];
                            return n.Column([
                              Slidable(
                                key: ValueKey(model.deviceId),
                                groupTag: '0',
                                closeOnScroll: true,
                                endActionPane: ActionPane(
                                  extentRatio:
                                      currentDid.value == model.deviceId
                                          ? 0.001
                                          : 0.25,
                                  motion: const BehindMotion(),
                                  children: [
                                    SlidableAction(
                                      key: ValueKey("delete_$index"),
                                      flex: 2,
                                      backgroundColor: Colors.red,
                                      // foregroundColor: Colors.white,
                                      onPressed: (_) async {
                                        n.showDialog(
                                          context: Get.context!,
                                          builder: (context) => n.Alert()
                                            ..content = SizedBox(
                                              height: 40,
                                              child: Center(
                                                  child: Text(
                                                      'delete_this_device_tips'
                                                          .tr)),
                                            )
                                            ..actions = [
                                              n.Button('button_cancel'.tr.n)
                                                ..style = n.NikuButtonStyle(
                                                  foregroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                )
                                                ..onPressed = () {
                                                  Navigator.of(context).pop();
                                                },
                                              n.Button('button_delete'.tr.n)
                                                ..onPressed = () async {
                                                  Navigator.of(context).pop();
                                                  bool res =
                                                      await logic.deleteDevice(
                                                    model.deviceId,
                                                  );
                                                  if (res) {
                                                    state.deviceList.removeAt(
                                                      state.deviceList
                                                          .indexWhere((e) =>
                                                              e.deviceId ==
                                                              model.deviceId),
                                                    );
                                                    EasyLoading.showSuccess(
                                                        'tip_success'.tr);
                                                  } else {
                                                    EasyLoading.showError(
                                                        'tip_failed'.tr);
                                                  }
                                                },
                                            ],
                                          barrierDismissible: true,
                                        );
                                      },
                                      label: 'button_delete'.tr,
                                      spacing: 1,
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsets.only(left: 0),
                                  title: n.Row([
                                    Text(model.deviceName),
                                    const Space(width: 10),
                                    if (currentDid.value == model.deviceId)
                                      Text(
                                        'current_device'.tr,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ]),
                                  subtitle: n.Row([
                                    Text(model.online
                                        ? 'online'.tr
                                        : 'offline'.tr),
                                    const Space(width: 10),
                                    if (model.lastActiveAt > 0)
                                      Text(
                                        DateTimeHelper.lastTimeFmt(
                                            model.lastActiveAtLocal),
                                      ),
                                  ]),
                                  trailing: navigateNextIcon,
                                  onTap: () {
                                    Get.to(
                                      () => UserDeviceDetailPage(
                                        model: model,
                                      ),
                                      transition: Transition.rightToLeft,
                                      popGesture: true, // 右滑，返回上一页
                                    );
                                  },
                                ),
                              ),
                              const HorizontalLine(height: 1.0),
                            ]);
                          },
                        );
                }),
              ),
            )
          ], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
