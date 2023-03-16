import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/repaint_boundary.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/scanner/scanner_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UqrcodePage extends StatelessWidget {
  final GlobalKey globalKey = GlobalKey();

  UqrcodePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // API_BASE_URL=https://dev.imboy.pub
    String qrdata =
        "$API_BASE_URL/uqrcode?id=${UserRepoLocal.to.currentUid}&$uqrcodeDataSuffix";

    int gender = UserRepoLocal.to.current.gender;

    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(
        title: "二维码名片".tr,
        rightDMActions: <Widget>[
          InkWell(
            child: const Padding(
              padding: EdgeInsets.only(left: 20, right: 10),
              child: Text(
                "...",
                style: TextStyle(
                  fontSize: 28,
                ),
              ),
            ),
            onTap: () {
              Get.bottomSheet(
                SizedBox(
                  width: Get.width,
                  height: Get.height * 0.25,
                  child: Wrap(
                    children: <Widget>[
                      Center(
                        child: TextButton(
                          child: Text(
                            '保存二维码'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          onPressed: () async {
                            String filename =
                                "${UserRepoLocal.to.currentUid}_qrcode.png";
                            RepaintBoundaryHelper().savePhoto(
                              globalKey,
                              filename,
                            );
                          },
                        ),
                      ),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Get.back();
                            Get.to(() => const ScannerPage());
                          },
                          child: Text(
                            '扫描二维码'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: TextButton(
                          onPressed: () => Get.back(),
                          child: Text(
                            'button_cancel'.tr,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              // color: Colors.white,
                              fontSize: 16.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
                backgroundColor: Colors.white,
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
      body: Padding(
        padding: const EdgeInsets.only(
          left: 20,
          top: 60,
          right: 20,
          bottom: 20,
        ),
        child: RepaintBoundary(
          key: globalKey,
          child: Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              width: Get.width,
              height: Get.height * 0.65,
              color: Colors.white,
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(10.0),
                        // color: defHeaderBgColor,
                        image:
                            dynamicAvatar(UserRepoLocal.to.current.avatar),
                      ),
                    ),
                    title: Text(UserRepoLocal.to.current.nickname),
                    subtitle: Text(UserRepoLocal.to.current.region),
                    trailing: genderIcon(gender),
                  ),
                  Expanded(
                    child: Center(
                      child: QrImage(
                        data: qrdata,
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
                        embeddedImage: cachedImageProvider(
                            UserRepoLocal.to.current.avatar),
                        // embeddedImage: AssetImage('assets/images/logo.png'),
                        embeddedImageStyle: QrEmbeddedImageStyle(
                          size: const Size.square(64),
                          // color: Colors.pink,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 20)
                            .copyWith(bottom: 20),
                    child: Text("扫一扫上面的二维码图案，加我为朋友".tr),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
