import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'storage_space_logic.dart';

//ignore: must_be_immutable
class StorageSpacePage extends StatelessWidget {
  StorageSpacePage({super.key});

  RxList items = [].obs;

  final logic = Get.put(StorageSpaceLogic());
  final state = Get.find<StorageSpaceLogic>().state;

  void initData() async {
    logic.initData();
  }

  @override
  Widget build(BuildContext context) {
    initData();

    return Scaffold(
      appBar: PageAppBar(
        title: 'storage_space'.tr,
      ),
      body: SingleChildScrollView(
        child: n.Padding(
          left: 16,
          right: 16,
          child: n.Column([
            n.Padding(
              top: 20,
              bottom: 10,
              child: n.Row([
                Obx(() => SizedBox(
                      height: 20,
                      width: Get.width *
                          (state.totalDiskSpace.value > 0
                              ? state.usedDiskSpace.value /
                                  state.totalDiskSpace.value
                              : 0),
                      child: LinearProgressIndicator(
                        value: state.appAllBytes.value > 0
                            ? (state.appAllBytes.value /
                                        state.usedDiskSpace.value >
                                    0.04
                                ? state.appAllBytes.value /
                                    state.usedDiskSpace.value
                                : 0.04)
                            : 0,
                        backgroundColor: Colors.amber,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    )),
                Expanded(
                    child: Obx(() => SizedBox(
                          height: 20,
                          width: state.totalDiskSpace.value > 0
                              ? (Get.width *
                                      (state.freeDiskSpace.value /
                                          state.totalDiskSpace.value)) -
                                  32
                              : 1,
                          child: const LinearProgressIndicator(
                            value: 1,
                            backgroundColor: Color(0xFF7E7F88),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black12),
                          ),
                        ))),
              ]),
            ),
            n.Row([
              const Icon(
                Icons.square,
                color: Colors.green,
                size: 12,
              ),
              const SizedBox(width: 4),
              Obx(() => Text(
                    appName +
                        'used_space'.tr +
                        formatBytes(
                          (state.appAllBytes.value),
                          num: 1000,
                        ),
                    style: const TextStyle(fontSize: 12),
                  )),
            ]),
            n.Row([
              const Icon(
                Icons.square,
                color: Colors.amber,
                size: 12,
              ),
              const SizedBox(width: 4),
              Obx(
                () => Text(
                  'device_used_space'.tr +
                      formatBytes(
                        state.usedDiskSpace.value,
                        num: 1000,
                      ),
                  style: const TextStyle(fontSize: 12),
                ),
              )
            ]),
            n.Row([
              const Icon(
                Icons.square,
                color: Colors.black12,
                size: 12,
              ),
              const SizedBox(width: 4),
              Obx(() => Text(
                    'device_available_space'.tr +
                        formatBytes(
                          state.freeDiskSpace.value,
                          num: 1000,
                        ),
                    style: const TextStyle(fontSize: 12),
                  )),
            ]),
            const SizedBox(height: 16),
            n.Column([
              n.Row([Text(appName + 'used_space'.tr)]),
              n.Row([
                Obx(
                  () => Text(
                    formatBytes(
                      state.appAllBytes.value,
                      num: 1000,
                    ),
                    style: const TextStyle(fontSize: 38),
                  ),
                )
              ]),
              n.Row([
                // 占设备 @percent‰ 存储空间(@total)
                Obx(() => Text('tip_device_space'.trArgs([
                      state.totalDiskSpace.value > 0
                          ? ((state.appAllBytes.value /
                                      state.totalDiskSpace.value) *
                                  1000)
                              .toStringAsFixed(3)
                          : '0',
                      formatBytes(
                        state.totalDiskSpace.value,
                        num: 1000,
                      ),
                    ])))
              ]),
            ]),
            const SizedBox(height: 8),
            n.Column([
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Container(
                  color: AppColors.primaryBackground,
                  child: n.ListTile(
                    title: n.Row([
                      Text(appName + 'cache'.tr),
                      const Expanded(child: SizedBox()),
                      ElevatedButton(
                        onPressed: () async {
                          bool res = await logic.clearAllCache();
                          if (res) {
                            EasyLoading.showSuccess('tip_success'.tr);
                          } else {
                            EasyLoading.showError('tip_failed'.tr);
                          }
                        },
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size(72, 26),
                          ),
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                          //取消圆角边框
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                        ),
                        child: Text(
                          // 'go_clean'.tr,
                          'clean'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryElement,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ]),
                    subtitle: n.Column([
                      n.Row([
                        Obx(
                          () => Text(
                            formatBytes(
                              state.cacheBytes.value,
                              num: 1000,
                            ),
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      ])
                        // 内容居左
                        ..mainAxisAlignment = MainAxisAlignment.start,
                      Text(
                        '缓存是使用APP过程中产生的临时数据，清理缓存不会影响你的正常使用。'.tr,
                        style:
                            const TextStyle(color: AppColors.thirdElementText),
                      )
                    ])
                      // 内容居左
                      ..mainAxisAlignment = MainAxisAlignment.start,
                  ),
                ),
              ),
              /*
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Container(
                  color: AppColors.primaryBackground,
                  child: n.ListTile(
                    title: n.Row([
                      Text('chat_history'.tr),
                      const Expanded(child: SizedBox()),
                      ElevatedButton(
                        onPressed: () {
                          Get.close();
                        },
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size(48, 26),
                          ),
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                          //取消圆角边框
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                        ),
                        child: Text(
                          'manage'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ]),
                    subtitle: n.Column([
                      n.Row([
                        Obx(
                          () => Text(
                            formatBytes(
                              state.chatHistoryBytes.value,
                              num: 1000,
                            ),
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      ])
                        // 内容居左
                        ..mainAxisAlignment = MainAxisAlignment.start,
                      Text(
                        // 当前账号本地生成的sqlite文件大小；可清理所选聊天记录里的图片、视频、和文件，或者清空所选聊天记录里的所有聊天信息。
                        appName +
                            'app_sqlite_file_size_explain'
                                .tr,
                        style:
                            const TextStyle(color: AppColors.thirdElementText),
                      )
                    ])
                      // 内容居左
                      ..mainAxisAlignment = MainAxisAlignment.start,
                  ),
                ),
              ),
              */
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Container(
                  color: AppColors.primaryBackground,
                  child: n.ListTile(
                    title: n.Row([
                      Text('user_data'.tr),
                      const Expanded(child: SizedBox()),
                      /* TODO 2024-01-29 17:42:21
                      ElevatedButton(
                        onPressed: () {
                          logic.pathList();
                        },
                        style: ButtonStyle(
                          minimumSize: MaterialStateProperty.all(
                            const Size(48, 26),
                          ),
                          padding: MaterialStateProperty.all(EdgeInsets.zero),
                          //取消圆角边框
                          shape:
                              MaterialStateProperty.all<RoundedRectangleBorder>(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4.0),
                            ),
                          ),
                        ),
                        child: Text(
                          'manage'.tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryText,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                      */
                    ]),
                    subtitle: n.Column([
                      n.Row([
                        Obx(
                          () => Text(
                            formatBytes(
                              state.dataBytes.value,
                              num: 1000,
                            ),
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      ])
                        // 内容居左
                        ..mainAxisAlignment = MainAxisAlignment.start,
                      Text(
                        '包含APP运行时必要的文件，以及聊天消息、好有关系等所有记录数据。'.tr,
                        style:
                            const TextStyle(color: AppColors.thirdElementText),
                      )
                    ])
                      // 内容居左
                      ..mainAxisAlignment = MainAxisAlignment.start,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Container(
                  color: AppColors.primaryBackground,
                  child: n.ListTile(
                    title: Text('app_size'.tr),
                    subtitle: n.Column([
                      n.Row([
                        Obx(
                          () => Text(
                            formatBytes(
                              state.appBytes.value,
                              num: 1000,
                            ),
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      ])
                        // 内容居左
                        ..mainAxisAlignment = MainAxisAlignment.start,
                      Text(
                        '包含APP运行的必要文件，包括 APK 文件、优化的编译器输出和解压的原生库。'.tr,
                        style:
                            const TextStyle(color: AppColors.thirdElementText),
                      )
                    ])
                      // 内容居左
                      ..mainAxisAlignment = MainAxisAlignment.start,
                  ),
                ),
              ),
            ])
              ..mainAxisSize = MainAxisSize.min
          ], mainAxisSize: MainAxisSize.min),
        ),
      ),
    );
  }
}
