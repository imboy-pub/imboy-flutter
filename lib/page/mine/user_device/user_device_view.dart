import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:niku/namespace.dart' as n;

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
    String tips = '你的帐号在以下设备中登录过，你可以删除设备，删除后在该设备登录时需进行安全验证。'.tr;
    return Scaffold(
      appBar: PageAppBar(
        title: '登录设备管理'.tr,
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
        //       '编辑'.tr,
        //     ),
        //   )
        // ],
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.primaryBackground,
          child: n.Column([
            n.Column([
              Container(
                width: Get.width,
                color: AppColors.AppBarColor,
                padding: const EdgeInsets.only(
                  top: 10.0,
                  left: 15,
                  right: 10,
                  bottom: 20,
                ),
                child: Text(
                  tips,
                  maxLines: 2,
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
                      ? NoDataView(text: '暂无数据'.tr)
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
                                        String tips =
                                            '删除后，下次在该设备登录时需要进行安全验证。'.tr;
                                        final alert = n.Alert()
                                          ..content = SizedBox(
                                            height: 40,
                                            child: Center(child: Text(tips)),
                                          )
                                          ..actions = [
                                            n.Button('取消'.tr.n)
                                              ..onPressed = () {
                                                Get.close(1);
                                              },
                                            n.Button('删除'.tr.n)
                                              ..onPressed = () async {
                                                bool res =
                                                    await logic.deleteDevice(
                                                  model.deviceId,
                                                );
                                                Get.close(2);
                                                if (res) {
                                                  state.deviceList.removeAt(
                                                    state.deviceList.indexWhere(
                                                        (e) =>
                                                            e.deviceId ==
                                                            model.deviceId),
                                                  );
                                                  EasyLoading.showSuccess(
                                                      '操作成功'.tr);
                                                } else {
                                                  EasyLoading.showError(
                                                      '操作失败'.tr);
                                                }
                                              },
                                          ];

                                        n.showDialog(
                                          context: Get.context!,
                                          builder: (context) => alert,
                                          barrierDismissible: true,
                                        );
                                      },
                                      label: "删除".tr,
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
                                        '当前设备'.tr,
                                        style: TextStyle(
                                          color: AppColors.MainTextColor
                                              .withOpacity(0.7),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ]),
                                  subtitle: n.Row([
                                    Text(model.online ? '在线'.tr : '离线'.tr),
                                    const Space(width: 10),
                                    if (model.lastActiveAt > 0)
                                      Text(
                                        DateTimeHelper.lastTimeFmt(
                                            model.lastActiveAt),
                                      ),
                                  ]),
                                  trailing: Icon(
                                    Icons.navigate_next,
                                    color: AppColors.MainTextColor.withOpacity(
                                        0.5),
                                  ),
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
                              const Divider(
                                height: 8.0,
                                indent: 0.0,
                                color: Colors.black26,
                              ),
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
