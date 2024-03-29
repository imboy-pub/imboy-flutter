import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/service/encrypter.dart';

// ignore: must_be_immutable
class MarkdownPage extends StatelessWidget {
  MarkdownPage({
    super.key,
    required this.title,
    required this.url,
    this.rightDMActions,
  });

  String title;
  String url;
  RxString content = "".obs;
  final List<Widget>? rightDMActions;

  void initData() async {
    File tmpF = await IMBoyCacheManager().getSingleFile(
      url,
      key: EncrypterService.md5(url),
    );
    content.value = await tmpF.readAsString();
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: NavAppBar(
        automaticallyImplyLeading: true,
        title: title,
        rightDMActions: rightDMActions,
      ),
      body: Container(
          color: Theme.of(context).colorScheme.background,
          child: Obx(
            () => Markdown(data: content.value),
          )),
    );
  }
}
