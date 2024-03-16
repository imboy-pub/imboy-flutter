import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/assets.dart';

class ImageView extends StatelessWidget {
  final String uri;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isRadius;

  const ImageView({
    super.key,
    required this.uri,
    this.height,
    this.width,
    this.fit,
    this.isRadius = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (isNetWorkImg(uri)) {
      image = CachedNetworkImage(
        imageUrl: AssetsService.viewUrl(uri).toString(),
        width: width,
        height: height,
        fit: fit,
        cacheManager: cacheManager,
      );
    } else if (File(uri).existsSync()) {
      image = Image.file(
        File(uri),
        width: width,
        height: height,
        fit: fit,
      );
    } else if (isAssetsImg(uri)) {
      image = Image(
        image: AssetImage(uri),
        width: width,
        height: height,
        fit: width != null && height != null ? BoxFit.fill : fit,
      );
    } else {
      image = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4.0),
          color: Colors.black26.withOpacity(0.1),
        ),
        child: Text('no_data'.tr),
      );
    }
    if (isRadius) {
      return ClipRRect(
        borderRadius: const BorderRadius.all(
          Radius.circular(4.0),
        ),
        child: image,
      );
    }
    return image;
  }
}
