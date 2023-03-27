import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'personal_info_logic.dart';
import 'personal_info_state.dart';
import 'update/update_view.dart';

class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _PersonalInfoPageState createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final logic = Get.put(PersonalInfoLogic());
  final PersonalInfoState state = Get.find<PersonalInfoLogic>().state;
  String currentUserAvatar = UserRepoLocal.to.current.avatar;

  ///拍摄照片
  Future fromCamera() async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      Get.back();
      Get.snackbar("提示", "网络连接异常");
      return;
    }
    await ImagePicker()
        .pickImage(source: ImageSource.camera)
        .then((avatarFile) {
      if (avatarFile != null) {
        return cropImage(avatarFile);
      }
    });
  }

  ///从相册选取
  Future fromGallery() async {
    // 检查网络状态
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      Get.back();
      Get.snackbar("提示", "网络连接异常");
      return;
    }
    await ImagePicker()
        .pickImage(source: ImageSource.gallery)
        .then((avatarFile) {
      if (avatarFile != null) {
        return cropImage(avatarFile);
      }
    });
  }

  void cropImage(XFile xfile) async {
    Get.back();
    File originalImage = File(xfile.path);

    String url = await Navigator.push(
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
    if (url.isNotEmpty) {
      bool ok = await logic.changeInfo({"field": "avatar", "value": url});
      if (ok) {
        //url是图片上传后拿到的url
        setState(() {
          currentUserAvatar = url;
          Map<String, dynamic> payload = UserRepoLocal.to.current.toMap();
          payload["avatar"] = url;
          UserRepoLocal.to.changeInfo(payload);
        });
      }
    }
  }

  Widget buildContent(item, UserModel user) {
    return LabelRow(
      label: item['title'],
      rValue: item['value'],
      isLine:
          item['label'] == 'address' || item['label'] == 'more' ? false : true,
      isRight: item['label'] == 'account' ? false : true,
      margin: EdgeInsets.only(bottom: item['label'] == 'more' ? 10.0 : 0.0),
      rightW: item['label'] == 'user_qrcode'
          ? const Icon(Icons.qr_code_2)
          : Container(),
      onPressed: () => logic.labelOnPressed(item['label']),
    );
  }

  @override
  Widget build(BuildContext context) {
    List data = [
      {
        'label': 'account',
        'title': '账号',
        'value': UserRepoLocal.to.current.account
      },
      {'label': 'user_qrcode', 'title': '二维码名片'.tr, 'value': ''},
      {'label': 'more', 'title': '更多信息'.tr, 'value': ''},
      // {'label': 'address', 'title': '我的地址'.tr, 'value': ''},
    ];

    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: '个人信息'.tr),
      body: SingleChildScrollView(
          child: Column(children: [
        LabelRow(
          label: '头像'.tr,
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
              height: Get.height * 0.25,
              child: Wrap(
                children: <Widget>[
                  Center(
                    child: TextButton(
                      onPressed: () => fromCamera(),
                      child: Text(
                        'button_taking_pictures'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          // color: Colors.white,
                          fontSize: 16.0,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => fromGallery(),
                      child: Text(
                        '从相册选择'.tr,
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
          ),
        ),
        LabelRow(
          label: '昵称'.tr,
          isLine: true,
          isRight: true,
          rightW: SizedBox(
            width: Get.width - 100,
            child: ExtendedText(
              UserRepoLocal.to.current.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: AppColors.MainTextColor.withOpacity(0.7),
                  fontWeight: FontWeight.w400),
            ),
          ),
          onPressed: () => Get.bottomSheet(
            UpdatePage(
                title: '设置昵称'.tr,
                value: UserRepoLocal.to.current.nickname,
                field: 'input',
                callback: (nickname) async {
                  bool ok = await logic
                      .changeInfo({"field": "nickname", "value": nickname});
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
            backgroundColor: Colors.white,
            // 是否支持全屏弹出，默认false
            isScrollControlled: true,
            enableDrag: false,
          ),
        ),
        Column(
          children: data
              .map((item) => buildContent(item, UserRepoLocal.to.current))
              .toList(),
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
