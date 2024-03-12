import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/component/ui/line.dart';

import 'package:imboy/store/repository/user_repo_local.dart';

import '../update/update_view.dart';
import 'personal_info_logic.dart';
import 'personal_info_state.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _PersonalInfoPageState createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final logic = Get.put(PersonalInfoLogic());
  final PersonalInfoState state = Get.find<PersonalInfoLogic>().state;
  String currentUserAvatar = UserRepoLocal.to.current.avatar;
  final ImagePickerPlatform _picker = ImagePickerPlatform.instance;

  Future getImageFromSource(ImageSource source) async {
    iPrint("getImageFromSource start");
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      Get.close();
      Get.snackbar('tip_tips'.tr, 'network_exception'.tr);
      return;
    }
    try {
      final XFile? avatarFile = await _picker.getImageFromSource(
        source: source,
      );

      iPrint("getImageFromSource ${avatarFile.toString()}");
      if (avatarFile != null) {
        return cropImage(avatarFile);
      }
    } catch (e) {
      iPrint("getImageFromSource e ${e.toString()}");
    }
  }

  void cropImage(XFile x) async {
    File originalImage = File(x.path);

    String? url = await Navigator.push(
      context,
      CupertinoPageRoute(
        // “右滑返回上一页”功能
        builder: (_) => CropImageRoute(
          originalImage,
          "avatar",
          filename: UserRepoLocal.to.current.uid,
        ),
      ),
    );

    debugPrint("> cropImage url $url;");
    if (strNoEmpty(url)) {
      Get.closeAllBottomSheets();
      bool ok = await logic.changeInfo({"field": "avatar", "value": url});
      if (ok) {
        //url是图片上传后拿到的url
        setState(() {
          currentUserAvatar = url!;
          Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
          payload["avatar"] = url;
          UserRepoLocal.to.changeInfo(payload);
        });
      }
    }
  }

  Widget buildContent(item) {
    return LabelRow(
      label: item['title'],
      rValue: item['value'],
      isLine:
          item['label'] == 'address' || item['label'] == 'more' ? false : true,
      isRight: item['isRight'] ?? true,
      margin: EdgeInsets.only(bottom: item['label'] == 'more' ? 10.0 : 0.0),
      rightW: item['label'] == 'user_qrcode'
          ? Icon(
              Icons.qr_code_2,
              color: Get.isDarkMode ? Colors.white70 : Colors.black,
            )
          : Container(),
      onPressed: () => logic.labelOnPressed(item['label']),
    );
  }

  @override
  Widget build(BuildContext context) {
    List data = [
      {
        'label': 'account',
        'title': 'account'.tr,
        'value': UserRepoLocal.to.current.account,
        'isRight': false
      },
      {'label': 'user_qrcode', 'title': 'my_qrcode'.tr, 'value': ''},
      {'label': 'more', 'title': 'more_info'.tr, 'value': ''},
      // {'label': 'address', 'title': 'my_address'.tr, 'value': ''},
    ];
    // if (UserRepoLocal.to.current.email.isNotEmpty) {
    data.insert(1, {
      'label': 'user_email',
      'title': 'login_email'.tr,
      'value': UserRepoLocal.to.current.email,
      'isRight': false
    });
    // }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
          automaticallyImplyLeading: true, title: 'personal_information'.tr),
      body: SingleChildScrollView(
          child: n.Column([
        LabelRow(
          label: 'avatar'.tr,
          isLine: true,
          isRight: true,
          rightW: SizedBox(
            width: 55.0,
            height: 55.0,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5.0)),
              child: Avatar(imgUri: currentUserAvatar),
            ),
          ),
          onPressed: () => Get.bottomSheet(
            SizedBox(
              width: Get.width,
              height: 168,
              child: n.Wrap([
                Center(
                  child: TextButton(
                    onPressed: () => getImageFromSource(ImageSource.camera),
                    child: Text(
                      'button_taking_pictures'.tr,
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
                    onPressed: () => getImageFromSource(ImageSource.gallery),
                    child: Text(
                      'choose_from_album'.tr,
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
            backgroundColor: Get.isDarkMode
                ? const Color.fromRGBO(80, 80, 80, 1)
                : const Color.fromRGBO(240, 240, 240, 1),
            //改变shape这里即可
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
          ),
        ),
        LabelRow(
            label: 'nickname'.tr,
            isLine: true,
            isRight: true,
            rightW: SizedBox(
              width: Get.width - 160,
              child: Text(
                UserRepoLocal.to.current.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w400),
              ),
            ),
            onPressed: () {
              Get.to(
                () => UpdatePage(
                    title: 'set_nickname'.tr,
                    value: UserRepoLocal.to.current.nickname,
                    field: 'input',
                    callback: (nickname) async {
                      bool ok = await logic.changeInfo({
                        "field": "nickname",
                        "value": nickname,
                      });
                      if (ok) {
                        //url是图片上传后拿到的url
                        setState(() {
                          Map<String, dynamic> payload =
                              UserRepoLocal.to.current.toMap();
                          payload["nickname"] = nickname;
                          UserRepoLocal.to.changeInfo(payload);
                        });
                      }
                      return ok;
                    }),
                transition: Transition.rightToLeft,
                popGesture: true, // 右滑，返回上一页,
              );
            }),
        n.Column(
          data.map((item) => buildContent(item)).toList(),
        ),
      ])),
    );
  }

  @override
  void dispose() {
    Get.delete<PersonalInfoLogic>();
    super.dispose();
  }
}
