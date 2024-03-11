import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/theme.dart';
import 'package:niku/namespace.dart' as n;
import 'package:qr_flutter/qr_flutter.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class UqrcodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  UqrcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    // API_BASE_URL=https://dev.imboy.pub
    String qrcodeData =
        "$API_BASE_URL/uqrcode?id=${UserRepoLocal.to.currentUid}&$userQrcodeDataSuffix";

    int gender = UserRepoLocal.to.current.gender;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                  height: 172,
                  child: n.Wrap([
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
                          String filename =
                              "${UserRepoLocal.to.currentUid}_qrcode.png";
                          RepaintBoundaryHelper().savePhoto(
                            context,
                            globalKey,
                            filename,
                          );
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
