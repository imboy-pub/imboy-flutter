import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/label_row.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/size_config.dart';
import 'package:imboy/page/qr_code/qr_code_view.dart';
import 'package:imboy/page/user/change_name/change_name_view.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repository.dart';

import 'personal_info_logic.dart';
import 'personal_info_state.dart';

class PersonalInfoPage extends StatefulWidget {
  @override
  _PersonalInfoPageState createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final logic = Get.put(PersonalInfoLogic());
  final PersonalInfoState state = Get.find<PersonalInfoLogic>().state;

  action(v) {
    if (v == '二维码名片') {
      Get.to(() => QrCodePage());
    } else {
      print(v);
    }
  }

  _openGallery({type = ImageSource.gallery}) async {
    final global = UserRepository.currentUser();
    File imageFile = (await ImagePicker().pickImage(source: type)) as File;
    List<int>? imageBytes = await compressFile(imageFile);
    if (imageFile != null) {
      String base64Img = 'data:image/jpeg;base64,${base64Encode(imageBytes!)}';
      logic.uploadImgApi(base64Img, (v) {
        if (v == null) {
          Get.snackbar("Tips", "上传头像失败,请换张图像再试");
          return;
        }
        logic.setUsersProfileMethod(
          avatarStr: v,
          nicknameStr: global.nickname!,
          callback: (data) {
            if (data.toString().contains('ucc')) {
              Get.snackbar("", "设置头像成功");
              global.avatar = v;
              // global.refresh();
            } else {
              Get.snackbar("", "设置头像失败");
            }
          },
        );
      });
    }
  }

  Widget dynamicAvatar(avatar, {size}) {
    if (isNetWorkImg(avatar)) {
      return new CachedNetworkImage(
          imageUrl: avatar,
          cacheManager: cacheManager,
          width: size ?? null,
          height: size ?? null,
          fit: BoxFit.fill);
    } else {
      return new Image.asset(avatar,
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
      new LabelRow(
        label: '头像',
        isLine: true,
        isRight: true,
        rightW: new SizedBox(
          width: 55.0,
          height: 55.0,
          child: new ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            child: strNoEmpty(global.avatar)
                ? dynamicAvatar(global.avatar)
                : new Image.asset(defIcon, fit: BoxFit.cover),
          ),
        ),
        onPressed: () => _openGallery(),
      ),
      new LabelRow(
        label: '昵称',
        isLine: true,
        isRight: true,
        rValue: global.nickname!,
        onPressed: () => Get.to(() => ChangeNamePage()),
      ),
      new Column(
        children: data.map((item) => buildContent(item, global)).toList(),
      ),
    ];

    return new Column(children: content);
  }

  Widget buildContent(item, UserModel user) {
    return new LabelRow(
      label: item['label'],
      rValue: item['value'],
      isLine: item['label'] == '我的地址' || item['label'] == '更多' ? false : true,
      isRight: item['label'] == '微信号' ? false : true,
      margin: EdgeInsets.only(bottom: item['label'] == '更多' ? 10.0 : 0.0),
      rightW: item['label'] == '二维码名片'
          ? new Image.asset('assets/images/mine/ic_small_code.png',
              color: mainTextColor.withOpacity(0.7))
          : new Container(),
      onPressed: () => action(item['label']),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(">>>>>>>>>>>>>>>>>>> on context ${context}");
    final model = UserRepository.currentUser();

    return new Scaffold(
      backgroundColor: appBarColor,
      appBar: new PageAppBar(title: '个人信息'),
      body: new SingleChildScrollView(child: body(model)),
    );
  }

  @override
  void dispose() {
    Get.delete<PersonalInfoLogic>();
    super.dispose();
  }
}
