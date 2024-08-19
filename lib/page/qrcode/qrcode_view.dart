import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:jiffy/jiffy.dart';
import 'package:niku/namespace.dart' as n;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/theme.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'qrcode_logic.dart';
import 'qrcode_state.dart';

class UserQrCodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  UserQrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    // API_BASE_URL=https://dev.imboy.pub
    String qrcodeData =
        "${Env.apiBaseUrl}/user/qrcode?id=${UserRepoLocal.to.currentUid}&$qrcodeDataSuffix";

    int gender = UserRepoLocal.to.current.gender;

    String filename = "${UserRepoLocal.to.currentUid}_qrcode";
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '',
        rightDMActions: <Widget>[
          InkWell(
            child: n.Padding(
              left: 20,
              right: 20,
              bottom: 20,
              child: const Text(
                "...",
                style: TextStyle(
                  fontSize: 28,
                ),
              ),
            ),
            onTap: () {
              Get.bottomSheet(
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                SizedBox(
                  width: Get.width,
                  height: 240,
                  child: n.Wrap([
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          // 使用addPostFrameCallback延迟截图操作到下一个frame
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) async {
                            final res = await RepaintBoundaryHelper()
                                .image(context, globalKey);
                            if (res != null) {
                              final result = await Share.shareXFiles(
                                [XFile.fromData(res, mimeType: 'png')],
                                text: 'scan_qrcode_add_friend'.tr,
                              );
                              if (result.status == ShareResultStatus.success) {}
                            }
                          });
                          Get.closeAllBottomSheets();
                          // Get.to(
                          //       () => const ScannerPage(),
                          //   transition: Transition.rightToLeft,
                          //   popGesture: true, // 右滑，返回上一页
                          // );
                        },
                        child: Text(
                          'share'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const Divider(),
                    Center(
                      child: TextButton(
                        child: Text(
                          'save_qr_code'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onPressed: () async {
                          // 使用addPostFrameCallback延迟截图操作到下一个frame
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) async {
                            final res = await RepaintBoundaryHelper().savePhoto(
                              context,
                              globalKey,
                              filename,
                            );
                            iPrint("savePhoto res ${res.toString()}");
                            bool isSuccess = res != null &&
                                    res is Map &&
                                    (res['isSuccess'] ?? false)
                                ? true
                                : false;
                            if (isSuccess) {
                              EasyLoading.showSuccess("save_success".tr);
                            }
                          });
                          Get.closeAllBottomSheets();
                        },
                      ),
                    ),
                    const Divider(),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Get.closeAllBottomSheets();
                          Get.to(
                            () => const ScannerPage(),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                        child: Text(
                          'scan_qr_code'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    HorizontalLine(
                      height: 6,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Get.close(),
                        child: Text(
                          'button_cancel'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                  ]),
                ),
                //改变shape这里即可
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: n.Padding(
        left: 20,
        top: 60,
        right: 20,
        bottom: 20,
        child: RepaintBoundary(
          key: globalKey,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadiusDirectional.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: Get.width,
              height: Get.height * 0.65 + 20,
              color: Colors.white,
              child: n.Column([
                ListTile(
                  leading: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(10.0),
                      // color: defHeaderBgColor,
                      image: dynamicAvatar(UserRepoLocal.to.current.avatar),
                    ),
                  ),
                  title: Text(
                    UserRepoLocal.to.current.nickname,
                    style: const TextStyle(
                      color: lightOnPrimaryColor,
                    ),
                  ),
                  subtitle: Text(
                    UserRepoLocal.to.current.region,
                    style: const TextStyle(
                      color: lightOnPrimaryColor,
                    ),
                  ),
                  trailing: genderIcon(gender),
                ),
                Expanded(
                  child: Center(
                    child: QrImageView(
                      data: qrcodeData,
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      size: 320,
                      padding: const EdgeInsets.only(
                        left: 10,
                        right: 10,
                        top: 10,
                        // bottom: 10,
                      ),
                      gapless: true,
                      //
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.circle,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.circle,
                        color: Colors.black,
                      ),
                      embeddedImage: Get.height < 640
                          ? null
                          : cachedImageProvider(
                              UserRepoLocal.to.current.avatar),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size.square(64),
                        // color: Colors.pink,
                      ),
                    ),
                  ),
                ),
                n.Padding(
                  // top: 10,
                  bottom: 15,
                  child: Text(
                    'scan_qrcode_add_friend'.tr,
                    style: const TextStyle(
                      color: lightOnPrimaryColor,
                    ),
                  ),
                ),
              ])
                // 内容居中
                ..mainAxisAlignment = MainAxisAlignment.center,
            ),
          ),
        ),
      ),
    );
  }
}

class GroupQrCodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  final int dayNum = 7;
  final GroupModel group;

  GroupQrCodePage({super.key, required this.group});

  final QrCodeLogic logic = Get.put(QrCodeLogic());
  final QrCodeState state = Get.find<QrCodeLogic>().state;

  Future<void> _initData() async {
    // API_BASE_URL=https://dev.imboy.pub
    int expiredAt = DateTimeHelper.utc() + dayNum * 86400 * 1000;
    String key = Env.solidifiedKey;
    String tk = EncrypterService.md5("${expiredAt}_$key");
    Map<String, dynamic> query = {
      'id': group.groupId,
      'exp': expiredAt,
      'tk': tk
    };
    String queryStr = query.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
    state.qrcodeData.value =
        "${Env.apiBaseUrl}/group/qrcode?$queryStr&$qrcodeDataSuffix";
    // iPrint("qrcodeData $expiredAt, $key, $tk; : ${expiredAt}_$key");
    // iPrint("qrcodeData ${state.qrcodeData.value}");

    state.expiredAt.value = expiredAt;
  }

  @override
  Widget build(BuildContext context) {
    _initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: '',
        rightDMActions: <Widget>[
          InkWell(
            child: n.Padding(
              left: 20,
              right: 20,
              bottom: 20,
              child: const Text(
                "...",
                style: TextStyle(
                  fontSize: 28,
                ),
              ),
            ),
            onTap: () {
              Get.bottomSheet(
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                SizedBox(
                  width: Get.width,
                  height: 240,
                  child: n.Wrap([
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          // 使用addPostFrameCallback延迟截图操作到下一个frame
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) async {
                            final res = await RepaintBoundaryHelper()
                                .image(context, globalKey);
                            if (res != null) {
                              // 该二维码%s天内（%s前）有效，重新进入将更新
                              final txt = 'group_qrcode_tips'.trArgs([
                                dayNum.toString(),
                                Jiffy.parseFromDateTime(
                                        Jiffy.parseFromMillisecondsSinceEpoch(
                                  state.expiredAt.value,
                                ).dateTime)
                                    .format(pattern: 'y-MM-dd')
                              ]);
                              final result = await Share.shareXFiles(
                                [XFile.fromData(res, mimeType: 'png')],
                                text: txt,
                              );
                              if (result.status == ShareResultStatus.success) {}
                            }
                          });
                          Get.closeAllBottomSheets();
                        },
                        child: Text(
                          'share'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    const Divider(),
                    Center(
                      child: TextButton(
                        child: Text(
                          'save_qr_code'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        onPressed: () async {
                          String filename = "${group.groupId}_qrcode.png";
                          // 使用addPostFrameCallback延迟截图操作到下一个frame
                          WidgetsBinding.instance
                              .addPostFrameCallback((_) async {
                            final res = await RepaintBoundaryHelper().savePhoto(
                              context,
                              globalKey,
                              filename,
                            );
                            iPrint("savePhoto res ${res.toString()}");
                            bool isSuccess = res != null &&
                                    res is Map &&
                                    (res['isSuccess'] ?? false)
                                ? true
                                : false;
                            if (isSuccess) {
                              EasyLoading.showSuccess("save_success".tr);
                            }
                          });
                          Get.closeAllBottomSheets();
                        },
                      ),
                    ),
                    const Divider(),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          Get.closeAllBottomSheets();
                          Get.to(
                            () => const ScannerPage(),
                            transition: Transition.rightToLeft,
                            popGesture: true, // 右滑，返回上一页
                          );
                        },
                        child: Text(
                          'scan_qr_code'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    HorizontalLine(
                      height: 6,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    Center(
                      child: TextButton(
                        onPressed: () => Get.close(),
                        child: Text(
                          'button_cancel'.tr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16.0,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ),
                    )
                  ]),
                ),
                //改变shape这里即可
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20.0),
                    topRight: Radius.circular(20.0),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 20,
          top: 20,
          right: 20,
          bottom: 20,
        ),
        child: n.Column([
          RepaintBoundary(
            key: globalKey,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: Obx(() => Container(
                    width: Get.width,
                    height: 520,
                    color: Colors.white,
                    child: n.Column([
                      n.Padding(
                        // top: 10,
                        bottom: 10,
                        child: ComputeAvatar(
                          imgUri: group.avatar,
                          computeAvatar: group.computeAvatar,
                        ),
                      ),
                      Flexible(
                          child: n.Padding(
                              // top: 20,
                              left: 10,
                              right: 10,
                              bottom: 20,
                              child: Text(
                                "${'group_chat'.tr}: ${group.title.isEmpty ? group.computeTitle : group.title}",
                                style: const TextStyle(
                                  color: lightOnPrimaryColor,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ))),
                      Center(
                        child: QrImageView(
                          data: state.qrcodeData.value,
                          version: QrVersions.auto,
                          errorCorrectionLevel: QrErrorCorrectLevel.H,
                          size: 320,
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            top: 10,
                            bottom: 10,
                          ),
                          gapless: true,
                          //
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.circle,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.circle,
                            color: Colors.black,
                          ),
                          embeddedImage: Get.height < 640
                              ? null
                              : const AssetImage('assets/images/3.0x/logo.png'),
                          embeddedImageStyle: const QrEmbeddedImageStyle(
                            size: Size.square(64),
                            // color: Colors.pink,
                          ),
                        ),
                      ),
                      n.Padding(
                        // top: 10,
                        left: 10, right: 10,
                        bottom: 10,
                        child: Text(
                          // 该二维码%s天内（%s前）有效，重新进入将更新
                          'group_qrcode_tips'.trArgs([
                            dayNum.toString(),
                            Jiffy.parseFromDateTime(
                                    Jiffy.parseFromMillisecondsSinceEpoch(
                                            state.expiredAt.value)
                                        .dateTime)
                                .format(pattern: 'y-MM-dd')
                          ]),
                          style: const TextStyle(
                            color: lightOnPrimaryColor,
                          ),
                        ),
                      ),
                    ])
                      // 内容居中
                      ..mainAxisAlignment = MainAxisAlignment.center,
                  )),
            ),
          ),
          Center(
            child: n.Row([
              TextButton(
                child: Text(
                  'save_qr_code'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                onPressed: () async {
                  String filename = "${group.groupId}_qrcode.png";
                  // 使用addPostFrameCallback延迟截图操作到下一个frame
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    final res = await RepaintBoundaryHelper().savePhoto(
                      context,
                      globalKey,
                      filename,
                    );
                    iPrint("savePhoto group res ${res.toString()}");
                    bool isSuccess =
                    res != null && res is Map && (res['isSuccess'] ?? false)
                        ? true
                        : false;
                    if (isSuccess) {
                      EasyLoading.showSuccess("save_success".tr);
                    }
                  });
                },
              ),
              TextButton(
                child: Text(
                  'share'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 16.0,
                    fontWeight: FontWeight.normal,
                  ),
                ),
                onPressed: () async {
                  // 使用addPostFrameCallback延迟截图操作到下一个frame
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) async {
                    final res = await RepaintBoundaryHelper()
                        .image(context, globalKey);
                    if (res != null) {
                      // 该二维码%s天内（%s前）有效，重新进入将更新
                      final txt = 'group_qrcode_tips'.trArgs([
                        dayNum.toString(),
                        Jiffy.parseFromDateTime(
                            Jiffy.parseFromMillisecondsSinceEpoch(
                              state.expiredAt.value,
                            ).dateTime)
                            .format(pattern: 'y-MM-dd')
                      ]);
                      final result = await Share.shareXFiles(
                        [XFile.fromData(res, mimeType: 'png')],
                        text: txt,
                      );
                      if (result.status == ShareResultStatus.success) {}
                    }
                  });
                },
              )
            ])
            // 两端对齐
              ..mainAxisAlignment = MainAxisAlignment.spaceBetween,
          )
        ]),
      ),
    );
  }
}
