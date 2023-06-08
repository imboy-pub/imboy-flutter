import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';

// ignore: must_be_immutable
class AboutIMBoyPage extends StatelessWidget {
  AboutIMBoyPage({super.key});

  RxString mdstring = "".obs;

  void initData() async {
    String uri = "https://gitee.com/imboy-pub/imboy-flutter/raw/main/README.md";
    File tmpF = await IMBoyCacheManager().getSingleFile(
      uri,
      key: EncrypterService.md5(uri),
    );
    mdstring.value = await tmpF.readAsString();
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(title: '关于IMBoy'.tr),
      body: Container(
          color: AppColors.primaryBackground,
          child: Obx(
            () => Markdown(data: mdstring.value),
          )),
    );
  }
}
