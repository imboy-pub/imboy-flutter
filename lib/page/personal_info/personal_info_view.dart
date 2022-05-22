import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/helper/crop_image.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/qr_code/qr_code_view.dart';
import 'package:imboy/page/user/change_name/change_name_view.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'personal_info_logic.dart';
import 'personal_info_state.dart';

class PersonalInfoPage extends StatefulWidget {
  @override
  _PersonalInfoPageState createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final logic = Get.put(PersonalInfoLogic());
  final PersonalInfoState state = Get.find<PersonalInfoLogic>().state;
  String currentUserAvatar = UserRepoLocal.to.currentUser.avatar!;

  action(v) {
    if (v == '二维码名片') {
      Get.to(() => QrCodePage());
    } else {
      print(v);
    }
  }

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
    File originalImage = await File(xfile.path);
    String url = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => CropImageRoute(
                  originalImage,
                  "avatar",
                  preferredSize: 600,
                  filename: UserRepoLocal.to.currentUser.uid!,
                )));
    if (url.isEmpty) {
      print('上传失败');
    } else {
      bool ok = await logic.changeInfo({"field": "avatar", "value": url});
      if (ok) {
        //url是图片上传后拿到的url
        setState(() {
          currentUserAvatar = url;
          Map<String, dynamic> payload = UserRepoLocal.to.currentUser.toJson();
          payload["avatar"] = url;
          UserRepoLocal.to.changeInfo(payload);
        });
      }
    }
  }

  Widget dynamicAvatar(avatar, {size}) {
    if (isNetWorkImg(avatar)) {
      return CachedNetworkImage(
          imageUrl: avatar,
          cacheManager: cacheManager,
          width: size ?? null,
          height: size ?? null,
          fit: BoxFit.fill);
    } else {
      return Image.asset(avatar,
          fit: BoxFit.fill, width: size ?? null, height: size ?? null);
    }
  }

  Widget body(UserModel global) {
    List data = [
      {'label': '账号', 'value': global.account},
      {'label': '二维码名片', 'value': ''},
      {'label': '更多', 'value': ''},
      {'label': '我的地址', 'value': ''},
    ];

    var content = [
      LabelRow(
        label: '头像',
        isLine: true,
        isRight: true,
        rightW: SizedBox(
          width: 55.0,
          height: 55.0,
          child: ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            child: strNoEmpty(currentUserAvatar)
                ? dynamicAvatar(currentUserAvatar)
                : Image.asset(defIcon, fit: BoxFit.cover),
          ),
        ),
        onPressed: () => Get.bottomSheet(
          Container(
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
                      style: TextStyle(
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
                      style: TextStyle(
                        // color: Colors.white,
                        fontSize: 16.0,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Divider(),
                Center(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    child: Text(
                      'button_cancel'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
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
        label: '昵称',
        isLine: true,
        isRight: true,
        rValue: UserRepoLocal.to.currentUser.nickname!,
        onPressed: () => Get.to(() => ChangeNamePage()),
      ),
      Column(
        children: data
            .map((item) => buildContent(item, UserRepoLocal.to.currentUser))
            .toList(),
      ),
    ];

    return Column(children: content);
  }

  Widget buildContent(item, UserModel user) {
    return LabelRow(
      label: item['label'],
      rValue: item['value'],
      isLine: item['label'] == '我的地址' || item['label'] == '更多' ? false : true,
      isRight: item['label'] == '微信号' ? false : true,
      margin: EdgeInsets.only(bottom: item['label'] == '更多' ? 10.0 : 0.0),
      rightW: item['label'] == '二维码名片'
          ? Image.asset('assets/images/mine/ic_small_code.png',
              color: AppColors.MainTextColor.withOpacity(0.7))
          : Container(),
      // onPressed: () => action(item['label']),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: '个人信息'),
      body: SingleChildScrollView(child: body(UserRepoLocal.to.currentUser)),
    );
  }

  @override
  void dispose() {
    Get.delete<PersonalInfoLogic>();
    super.dispose();
  }
}
