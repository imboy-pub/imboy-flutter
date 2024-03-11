import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:niku/namespace.dart' as n;
import 'package:permission_handler/permission_handler.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';

class UpgradePage extends StatefulWidget {
  /// apk更新url
  final String downLoadUrl;

  /// apk更新描述
  final String message;
  final String version;

  /// apk是否强制更新
  final bool isForce;

  const UpgradePage({
    super.key,
    required this.downLoadUrl,
    required this.message,
    required this.version,
    required this.isForce,
  });

  @override
  UpgradePageState createState() => UpgradePageState();
}

class UpgradePageState extends State<UpgradePage> {
  int downloadId = 0;
  UpgradeCard? _upgradeCard;
  String downloadKey = 'downloaderSendPort';

  String? positiveBtn;
  GestureTapCallback? positiveCallback;
  double progress = 0; // [0, 1]

  String? speed;
  double? planTime;
  int maxLength = 0;
  int currentLength = 0;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      RUpgrade.stream.listen((DownloadInfo info) {
        iPrint("RUpgrade.stream.listen info ${info.toString()}");
        // 更新进度条
        if (info.status == DownloadStatus.STATUS_PAUSED) {
          // STATUS_PAUSED 下载已暂停
          positiveBtn = 'continue_downloading'.tr;
          positiveCallback = upgradeWithId;
        } else if (info.status == DownloadStatus.STATUS_PENDING) {
          //  STATUS_PENDING等待下载
          positiveBtn = 'waiting_download'.tr;
          positiveCallback = pause;
          progress = 0;
        } else if (info.status == DownloadStatus.STATUS_RUNNING) {
          // STATUS_RUNNING下载中
          positiveBtn = 'pause_downloading'.tr;
          positiveCallback = pause;
          progress = (info.percent ?? 0) / 100;
          maxLength = info.maxLength!;
          currentLength = info.currentLength!;
          speed = info.getSpeedString();
          planTime = info.planTime;
        } else if (info.status == DownloadStatus.STATUS_SUCCESSFUL) {
          // STATUS_SUCCESSFUL下载成功
          positiveBtn = 'install_now'.tr;
          progress = 1;
          positiveCallback = install;
        } else if (info.status == DownloadStatus.STATUS_FAILED) {
          //   STATUS_FAILED下载失败
          positiveBtn = 'continue_downloading'.tr;
          positiveCallback = upgradeWithId;
        }
        // STATUS_CANCEL下载取消

        _upgradeCard?.updateProgress(
          hasLinearProgress: true,
          progress: progress,
          positiveBtn: positiveBtn,
          positiveCallback: positiveCallback,
          speed: speed,
          planTime: planTime,
          maxLength: maxLength,
          currentLength: currentLength,
        );
      });
    } else if (Platform.isIOS) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  // 初始化弹框文案
  initGeneral() {
    _upgradeCard?.updateProgress(
      title: 'new_version_detected'.tr + widget.version,
      message: widget.message,
      positiveBtn: 'update_now'.tr,
      negativeBtn: 'remind_me_later'.tr,
      hasLinearProgress: true,
      progress: 0,
    );
  }

  //检查权限
  Future<bool> _checkPermission() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      EasyLoading.show(status: "Permission 只支持 Android 和 IOS");
      return false;
    }
    //判断如果还没拥有读写权限就申请获取权限
    if (await Permission.storage.request().isDenied) {
      await Permission.storage.request();
      if ((await Permission.storage.status) != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  // 停止下载器运行（注销当前taskID）
  closeCallback() {
    Navigator.of(context).pop();
    if (downloadId > 0) cancel(downloadId);
  }

  // 3. 取消下载
  void cancel(int id) async {
    bool? isSuccess = await RUpgrade.cancel(id);
    iPrint("upgrade_cancel $id isSuccess $isSuccess");
  }

  //第一步：点击更新按钮
  _updateApplication() async {
    if (await _checkPermission()) {
      if (Platform.isAndroid) {
        initGeneral();
        upgradeApk(widget.downLoadUrl);
      } else if (Platform.isIOS) {
        upgradeFromAppStore();
      }
    } else {
      EasyLoading.showError('permission_acquisition_failed'.tr);
    }
  }

  Future<bool> upgradeApk(String url, [bool showNotification = true]) async {
    bool isDownloadFinish = false; //判断是否已经下载完成
    int? lastId = await RUpgrade.getLastUpgradedId();
    if (lastId != null) {
      downloadId = lastId;
      final status = await RUpgrade.getDownloadStatus(downloadId);
      if (status == DownloadStatus.STATUS_SUCCESSFUL) {
        isDownloadFinish = true;
        await RUpgrade.upgradeWithId(downloadId);
      } else if (status == DownloadStatus.STATUS_FAILED) {
        downloadId = (await RUpgrade.upgrade(
          url,
          fileName: '$appName${widget.version}.apk',
          useDownloadManager: false,
          notificationVisibility: showNotification == true
              ? NotificationVisibility.VISIBILITY_VISIBLE
              : NotificationVisibility.VISIBILITY_HIDDEN,
        ))!;
      } else {
        await RUpgrade.upgradeWithId(downloadId);
      }
    } else {
      downloadId = (await RUpgrade.upgrade(
        url,
        fileName: '$appName${widget.version}.apk',
        useDownloadManager: false,
        notificationVisibility: showNotification == true
            ? NotificationVisibility.VISIBILITY_VISIBLE
            : NotificationVisibility.VISIBILITY_HIDDEN,
      ))!;
    }
    return isDownloadFinish;
  }

  // ios 点击立即更新调整到 applly APP Store
  void upgradeFromAppStore() async {
    bool? isSuccess = await RUpgrade.upgradeFromAppStore(
      IOS_APP_ID,
    );
    if (isSuccess == false) {
      EasyLoading.showError(
        'ios_app_id_unknown'.trArgs([IOS_APP_ID]),
      );
      return;
    }
    closeCallback();
    iPrint("upgrade_upgradeFromAppStore isSuccess $isSuccess");
  }

  //第三步：下载失败或开始安装
  void againDownloader() async {
    downloadId = (await RUpgrade.getLastUpgradedId())!;
  }

  install() async {
    bool? isSuccess = await RUpgrade.install(downloadId);
    iPrint("upgrade_install $downloadId isSuccess $isSuccess");
  }

  // 使用文件路径进行安装应用
  installByPath(String path) async {
    bool? isSuccess = await RUpgrade.installByPath(path);
    iPrint("upgrade_installByPath $downloadId isSuccess $isSuccess");
  }

  // 暂停下载
  void pause() async {
    bool? isSuccess = await RUpgrade.pause(downloadId);
    iPrint("upgrade_pause $downloadId isSuccess $isSuccess");
  }

  // 继续下载
  void upgradeWithId() async {
    bool? isSuccess = await RUpgrade.upgradeWithId(downloadId);
    iPrint("upgrade_upgradeWithId $downloadId isSuccess $isSuccess");
    // 返回 false 即表示从来不存在此ID
    // 返回 true
    //    调用此方法前状态为 [STATUS_PAUSED]、[STATUS_FAILED]、[STATUS_CANCEL],将继续下载
    //    调用此方法前状态为 [STATUS_RUNNING]、[STATUS_PENDING]，不会发生任何变化
    //    调用此方法前状态为 [STATUS_SUCCESSFUL]，将会安装应用
    // 当文件被删除时，重新下载
  }

  // 1.获取应用商店列表
  void getAndroidStores() async {
    final stores = await RUpgrade.androidStores;
    iPrint("upgrade_getAndroidStores ${stores.toString()}");
  }

  // 3.跳转到应用商店升级
  Future<void> upgradeFromAndroidStore() async {
    bool? isSuccess = await RUpgrade.upgradeFromAndroidStore(
      AndroidStore.BAIDU,
    );
    iPrint("upgrade_upgradeFromAndroidStore isSuccess $isSuccess");
  }

  @override
  Widget build(BuildContext context) {
    if (_upgradeCard != null) {
      return _upgradeCard!;
    }
    return _upgradeCard = UpgradeCard(
      title: 'new_version_detected'.tr + widget.version,
      message: widget.message,
      positiveBtn: 'update_now'.tr,
      negativeBtn: widget.isForce ? '' : 'remind_me_later'.tr,
      positiveCallback: () => _updateApplication(),
      // positiveCallback: () => getAndroidStores(),
      negativeCallback: () => closeCallback(),
    );
  }
}

// ignore: must_be_immutable
class UpgradeCard extends StatefulWidget {
  ///标题
  String title;

  ///更新内容
  String message;

  ///确认按钮
  String positiveBtn;

  ///取消按钮
  String negativeBtn;

  ///确定按钮回调
  GestureTapCallback positiveCallback;

  ///取消按钮回调
  final GestureTapCallback negativeCallback;

  ///条形下载进度条，默认不展示
  bool hasLinearProgress;
  double progress = 0;

  String? speed;
  double? planTime;
  int currentLength = 0;
  int maxLength = 0;

  UpgradeCard({
    super.key,
    required this.positiveCallback,
    required this.negativeCallback,
    this.title = "",
    this.message = "",
    this.positiveBtn = "",
    this.negativeBtn = "",
    this.hasLinearProgress = false,
    this.progress = 0,
  });

  final upgradeCardState = UpgradeCardState();

  @override
  UpgradeCardState createState() => upgradeCardState;

  /// 外部更新函数
  void updateProgress(
          {required bool hasLinearProgress,
          required double progress,
          String? title,
          String? message,
          String? positiveBtn,
          String? negativeBtn,
          GestureTapCallback? positiveCallback,
          String? speed,
          double? planTime,
          int? maxLength,
          int? currentLength}) =>
      upgradeCardState.updateProgress(
        title: title,
        message: message,
        positiveBtn: positiveBtn,
        negativeBtn: negativeBtn,
        hasLinearProgress: hasLinearProgress,
        progress: progress,
        positiveCallback: positiveCallback,
        speed: speed,
        planTime: planTime,
        maxLength: maxLength,
        currentLength: currentLength,
      );
}

class UpgradeCardState extends State<UpgradeCard> {
  /// 内部更新函数
  void updateProgress({
    required bool hasLinearProgress,
    required double progress,
    String? title,
    String? message,
    String? positiveBtn,
    String? negativeBtn,
    GestureTapCallback? positiveCallback,
    String? speed,
    double? planTime,
    int? maxLength,
    int? currentLength,
  }) {
    if (!mounted) {
      return;
    }
    setState(() {
      if (title != null) {
        widget.title = title;
      }
      if (message != null) {
        widget.message = message;
      }
      if (positiveBtn != null) {
        widget.positiveBtn = positiveBtn;
      }
      if (negativeBtn != null) {
        widget.negativeBtn = negativeBtn;
      }
      if (positiveCallback != null) {
        widget.positiveCallback = positiveCallback;
      }
      if (speed != null) {
        widget.speed = speed;
      }
      if (planTime != null) {
        widget.planTime = planTime;
      }
      if (maxLength != null) {
        widget.maxLength = maxLength;
      }
      if (currentLength != null) {
        widget.currentLength = currentLength;
      }
      widget.hasLinearProgress = hasLinearProgress;
      widget.progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: Get.width - 20,
        padding: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            //背景图片
            // Container(
            //   padding: const EdgeInsets.only(bottom: 8),
            //   child: ClipRRect(
            //     borderRadius: BorderRadius.circular(8),
            //     child: Image.asset(
            //       "assets/images/updateBg.png",
            //       width: 320,
            //     ),
            //   ),
            // ),

            ///标题
            Visibility(
              visible: widget.title.isNotEmpty,
              child: Container(
                padding: const EdgeInsets.only(top: 25),
                child: Text(
                  widget.title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color: Color(0xFF333130)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            ///更新内容
            Container(
                width: Get.width - 40,
                height: Get.height - 200,
                margin: const EdgeInsets.all(8),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SelectableText.rich(
                      TextSpan(
                        text: widget.message.isEmpty
                            ? 'no_update_description'.tr
                            : widget.message,
                        // style: const TextStyle(
                        //   color: Colors.black,
                        //   fontSize: 16,
                        // ),
                      ),
                      textAlign: widget.message.isEmpty
                          ? TextAlign.center
                          : TextAlign.left,
                    ),
                  ),
                )),
            SizedBox(
              height: 44,
              width: Get.width - 40,
              // margin: const EdgeInsets.only(bottom: 0),
              child: widget.planTime == null
                  ? const SizedBox.shrink()
                  : n.Column([
                      n.Row([
                        Text(
                            "${'package_size'.tr} ${(widget.maxLength / 1024 / 1024).toStringAsFixed(3)}MB"),
                        const Expanded(child: SizedBox()),
                        Text(
                            "${'still_needed'.tr} ${(widget.planTime!).toStringAsFixed(3)}秒"),
                      ]),
                      n.Row([
                        Text(
                            "${'downloaded'.tr} ${(widget.currentLength / 1024 / 1024).toStringAsFixed(3)}MB"),
                        const Expanded(child: SizedBox()),
                        Text('speed'.tr + widget.speed!),
                      ]),
                    ]),
            ),

            // 进度条
            Container(
              height: 8,
              width: Get.width - 40,
              margin: const EdgeInsets.only(bottom: 20),
              child: widget.hasLinearProgress
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(Colors.blue),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            ///按钮列表
            SizedBox(
              height: 40,
              child: Row(children: <Widget>[
                Visibility(
                  visible: widget.negativeBtn.isNotEmpty,
                  child: Expanded(
                    child: TextButton(
                      onPressed: widget.negativeCallback,
                      child: Text(
                        widget.negativeBtn,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 40,
                  width: 0.5,
                  color: const Color(0xffC0C5D6),
                ),
                Visibility(
                    visible: widget.positiveBtn.isNotEmpty,
                    child: Expanded(
                      child: TextButton(
                        onPressed: widget.positiveCallback,
                        child: Text(widget.positiveBtn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              // color: Color.fromARGB(255, 64, 75, 130),
                            )),
                      ),
                    ))
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
