import 'dart:async';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:r_upgrade/r_upgrade.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/app_upgrade_log_api.dart';
import 'package:imboy/theme/default/app_radius.dart';

class UpgradePage extends ConsumerStatefulWidget {
  /// apk更新url
  final String downLoadUrl;

  /// apk更新描述
  final String message;
  final String version;

  /// apk是否强制更新
  final bool isForce;

  /// 安装包 SHA256 校验值（可选，非空时校验）
  final String fileHash;

  const UpgradePage({
    super.key,
    required this.downLoadUrl,
    required this.message,
    required this.version,
    required this.isForce,
    this.fileHash = '',
  });

  @override
  ConsumerState<UpgradePage> createState() => UpgradePageState();
}

class UpgradePageState extends ConsumerState<UpgradePage> {
  int downloadId = 0;
  UpgradeCard? _upgradeCard;
  String downloadKey = 'downloaderSendPort';

  String? positiveBtn;
  GestureTapCallback? positiveCallback;
  double progress = 0; // [0, 1]

  /// SHA256 校验重试次数
  int _hashRetryCount = 0;
  static const int _maxHashRetry = 2;

  String? speed;
  double? planTime;
  int maxLength = 0;
  int currentLength = 0;

  StreamSubscription<dynamic>? _localeSubscription;
  StreamSubscription<dynamic>? _downloadSubscription; // 下载进度订阅

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
    // RUpgrade.setDebug(true);
    if (Platform.isAndroid) {
      _downloadSubscription = RUpgrade.stream.listen((DownloadInfo info) {
        if (kDebugMode) iPrint("RUpgrade.stream status: ${info.status}");
        // 更新进度条
        if (info.status == DownloadStatus.STATUS_PAUSED) {
          // STATUS_PAUSED 下载已暂停
          positiveBtn = t.common.continueDownloading;
          positiveCallback = upgradeWithId;
        } else if (info.status == DownloadStatus.STATUS_PENDING) {
          //  STATUS_PENDING等待下载
          positiveBtn = t.common.waitingDownload;
          positiveCallback = pause;
          progress = 0;
        } else if (info.status == DownloadStatus.STATUS_RUNNING) {
          // STATUS_RUNNING下载中
          positiveBtn = t.common.pauseDownloading;
          positiveCallback = pause;
          progress = (info.percent ?? 0) / 100;
          maxLength = info.maxLength!;
          currentLength = info.currentLength!;
          speed = info.getSpeedString();
          planTime = info.planTime;
        } else if (info.status == DownloadStatus.STATUS_SUCCESSFUL) {
          // STATUS_SUCCESSFUL下载成功
          progress = 1;
          AppUpgradeLogApi.report(
            event: 'download_done',
            targetVsn: widget.version,
          );
          // 有 fileHash 时先校验，无则直接安装
          if (widget.fileHash.isNotEmpty && info.path != null) {
            positiveBtn = t.common.installNow;
            positiveCallback = () => _verifyAndInstall(info.path!);
          } else {
            positiveBtn = t.common.installNow;
            positiveCallback = install;
          }
        } else if (info.status == DownloadStatus.STATUS_FAILED) {
          //   STATUS_FAILED下载失败
          AppUpgradeLogApi.report(
            event: 'error',
            targetVsn: widget.version,
            extra: {'reason': 'download_failed'},
          );
          positiveBtn = t.common.continueDownloading;
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
    _localeSubscription?.cancel();
    _downloadSubscription?.cancel(); // 清理下载进度订阅
    super.dispose();
  }

  // 初始化弹框文案
  void initGeneral() {
    _upgradeCard?.updateProgress(
      // 使用字符串替换的方式传递版本号参数
      title: t.common.newVersionDetectedWithVersion(param: widget.version),
      message: widget.message,
      positiveBtn: t.common.updateNow,
      negativeBtn: t.chat.remindMeLater,
      hasLinearProgress: true,
      progress: 0,
    );
  }

  //检查权限
  Future<bool> _checkPermission() async {
    // Web 平台不需要检查权限
    if (kIsWeb) {
      return true;
    }
    if (!(Platform.isAndroid || Platform.isIOS)) {
      EasyLoading.show(status: t.common.permissionOnlySupportAndroidAndIos);
      return false;
    }
    PermissionStatus status;
    if (Platform.isAndroid) {
      final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
      final AndroidDeviceInfo info = await deviceInfoPlugin.androidInfo;
      iPrint("_checkPermission info.version.sdkInt ${info.version.sdkInt}");
      if ((info.version.sdkInt) >= 33) {
        // Android 13+ 使用应用私有目录下载 APK，不再依赖旧版存储权限。
        return true;
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.storage.request();
    }
    iPrint("_checkPermission status ${status.toString()}");

    switch (status) {
      case PermissionStatus.denied:
        return false;
      case PermissionStatus.granted:
        return true;
      case PermissionStatus.restricted:
        return false;
      case PermissionStatus.limited:
        return true;
      case PermissionStatus.permanentlyDenied:
        return false;
      case PermissionStatus.provisional:
        return true;
    }
  }

  // 停止下载器运行（注销当前taskID）
  void closeCallback() {
    AppUpgradeLogApi.report(event: 'cancel', targetVsn: widget.version);
    Navigator.of(context).pop();
    if (downloadId > 0) cancel(downloadId);
  }

  // 3. 取消下载
  Future<void> cancel(int id) async {
    bool? isSuccess = await RUpgrade.cancel(id);
    iPrint("upgrade_cancel $id isSuccess $isSuccess");
  }

  //第一步：点击更新按钮
  Future<void> _updateApplication() async {
    if (await _checkPermission()) {
      if (Platform.isAndroid) {
        AppUpgradeLogApi.report(
          event: 'download_start',
          targetVsn: widget.version,
        );
        initGeneral();
        upgradeApk(widget.downLoadUrl);
      } else if (Platform.isIOS) {
        upgradeFromAppStore();
      }
    } else {
      EasyLoading.showError(t.common.permissionAcquisitionFailed);
    }
  }

  Future<bool> upgradeApk(String url, [bool showNotification = true]) async {
    bool isDownloadFinish = false; //判断是否已经下载完成
    int? lastId = await RUpgrade.getLastUpgradedId();
    iPrint("upgradeApk_ $lastId;");
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
  Future<void> upgradeFromAppStore() async {
    bool? isSuccess = await RUpgrade.upgradeFromAppStore(Env().iosAppId);
    if (isSuccess == false) {
      EasyLoading.showError(t.common.iosAppIdUnknown(param: Env().iosAppId));
      return;
    }
    closeCallback();
    iPrint("upgrade_upgradeFromAppStore isSuccess $isSuccess");
  }

  //第三步：下载失败或开始安装
  Future<void> againDownloader() async {
    downloadId = (await RUpgrade.getLastUpgradedId())!;
  }

  Future<void> install() async {
    AppUpgradeLogApi.report(event: 'install', targetVsn: widget.version);
    bool? isSuccess = await RUpgrade.install(downloadId);
    iPrint("upgrade_install $downloadId isSuccess $isSuccess");
  }

  // 使用文件路径进行安装应用
  Future<void> installByPath(String path) async {
    bool? isSuccess = await RUpgrade.installByPath(path);
    iPrint("upgrade_installByPath $downloadId isSuccess $isSuccess");
  }

  /// 校验下载文件 SHA256 后安装
  ///
  /// 校验失败时自动删除文件并重试下载（最多 [_maxHashRetry] 次）
  Future<void> _verifyAndInstall(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        EasyLoading.showError(t.common.downloadFileNotFound);
        _retryDownload();
        return;
      }

      final bytes = await file.readAsBytes();
      final digest = sha256.convert(bytes);
      final computedHash = digest.toString();

      // 服务端可能返回 "sha256:abcdef..." 或纯 hash
      final expectedHash = widget.fileHash.startsWith('sha256:')
          ? widget.fileHash.substring(7)
          : widget.fileHash;

      if (computedHash == expectedHash) {
        iPrint('SHA256 校验通过: $computedHash');
        AppUpgradeLogApi.report(event: 'verify_ok', targetVsn: widget.version);
        install();
      } else {
        iPrint('SHA256 校验失败: expected=$expectedHash, got=$computedHash');
        AppUpgradeLogApi.report(
          event: 'verify_fail',
          targetVsn: widget.version,
          extra: {
            'expected': expectedHash.substring(0, 8),
            'got': computedHash.substring(0, 8),
          },
        );
        await file.delete();
        _retryDownload();
      }
    } on Exception catch (e) {
      if (kDebugMode) iPrint('SHA256 校验异常: ${e.runtimeType}');
      AppUpgradeLogApi.report(
        event: 'verify_exception',
        targetVsn: widget.version,
        extra: {'error': e.runtimeType.toString()},
      );
      // 校验异常时删除文件并重试，不允许安装未校验的文件
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } on Exception catch (_) {}
      _retryDownload();
    }
  }

  /// 校验失败后重试下载
  void _retryDownload() {
    _hashRetryCount++;
    if (_hashRetryCount <= _maxHashRetry) {
      EasyLoading.showError(
        t.common.downloadHashRetrying(
          retry: _hashRetryCount,
          max: _maxHashRetry,
        ),
      );
      upgradeApk(widget.downLoadUrl);
    } else {
      EasyLoading.showError(t.common.downloadHashFailed);
      _hashRetryCount = 0;
    }
  }

  // 暂停下载
  Future<void> pause() async {
    bool? isSuccess = await RUpgrade.pause(downloadId);
    iPrint("upgrade_pause $downloadId isSuccess $isSuccess");
  }

  // 继续下载
  Future<void> upgradeWithId() async {
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
  Future<void> getAndroidStores() async {
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
    final t = context.t;
    if (_upgradeCard != null) {
      return widget.isForce
          ? PopScope(canPop: false, child: _upgradeCard!)
          : _upgradeCard!;
    }
    _upgradeCard = UpgradeCard(
      title: t.common.newVersionDetected + widget.version,
      message: widget.message,
      positiveBtn: t.common.updateNow,
      negativeBtn: widget.isForce ? '' : t.chat.remindMeLater,
      positiveCallback: () => _updateApplication(),
      negativeCallback: () => closeCallback(),
    );
    return widget.isForce
        ? PopScope(canPop: false, child: _upgradeCard!)
        : _upgradeCard!;
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
  // ignore: no_logic_in_create_state
  UpgradeCardState createState() => upgradeCardState;

  /// 外部更新函数
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
  }) => upgradeCardState.updateProgress(
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
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width - 20,
        padding: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: AppRadius.borderRadiusSmall,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ///标题
            Visibility(
              visible: widget.title.isNotEmpty,
              child: Container(
                padding: const EdgeInsets.only(top: 25),
                child: Text(
                  widget.title,
                  style: context
                      .textStyle(
                        FontSizeType.large,
                        fontWeight: FontWeight.w600,
                        color: AppColors.upgradeBackground,
                      )
                      .copyWith(decoration: TextDecoration.none),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            ///更新内容
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height - 200,
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width - 40,
                  margin: AppSpacing.allSmall,
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SelectableText.rich(
                        TextSpan(
                          text: widget.message.isEmpty
                              ? t.common.noUpdateDescription
                              : widget.message,
                        ),
                        textAlign: widget.message.isEmpty
                            ? TextAlign.center
                            : TextAlign.left,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 44,
              width: MediaQuery.of(context).size.width - 40,
              child: widget.planTime == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              "${t.main.packageSize} ${(widget.maxLength / 1024 / 1024).toStringAsFixed(3)}MB",
                            ),
                            const Spacer(),
                            Text(
                              "${t.main.stillNeeded} ${(widget.planTime!).toStringAsFixed(3)}${t.common.seconds}",
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              "${t.common.downloaded} ${(widget.currentLength / 1024 / 1024).toStringAsFixed(3)}MB",
                            ),
                            const Spacer(),
                            Text(t.main.speed + widget.speed!),
                          ],
                        ),
                      ],
                    ),
            ),

            // 进度条
            Container(
              height: 8,
              width: MediaQuery.of(context).size.width - 40,
              margin: const EdgeInsets.only(bottom: 20),
              child: widget.hasLinearProgress
                  ? ClipRRect(
                      borderRadius: AppRadius.borderRadiusSmall,
                      child: LinearProgressIndicator(
                        value: widget.progress,
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkSurfaceContainer
                            : AppColors.lightSurfaceContainer,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.iosBlue,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            ///按钮列表
            SizedBox(
              height: 40,
              child: Row(
                children: <Widget>[
                  Visibility(
                    visible: widget.negativeBtn.isNotEmpty,
                    child: Expanded(
                      child: TextButton(
                        onPressed: widget.negativeCallback,
                        child: Text(
                          widget.negativeBtn,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w500,
                            color: AppColors.iosGray,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 40,
                    width: 0.5,
                    color: AppColors.lightDivider,
                  ),
                  Visibility(
                    visible: widget.positiveBtn.isNotEmpty,
                    child: Expanded(
                      child: TextButton(
                        onPressed: widget.positiveCallback,
                        child: Text(
                          widget.positiveBtn,
                          style: context.textStyle(
                            FontSizeType.medium,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
