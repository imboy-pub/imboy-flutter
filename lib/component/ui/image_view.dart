import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';

class ImageView extends StatelessWidget {
  final String img;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final bool isRadius;

  const ImageView({Key? key,
    required this.img,
    this.height,
    this.width,
    this.fit,
    this.isRadius = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (isNetWorkImg(img)) {
      image = CachedNetworkImage(
        imageUrl: img,
        width: width,
        height: height,
        fit: fit,
        cacheManager: cacheManager,
      );
    } else if (File(img).existsSync()) {
      image = Image.file(
        File(img),
        width: width,
        height: height,
        fit: fit,
      );
    } else if (isAssetsImg(img)) {
      image = Image(
        image: AssetImage(img),
        width: width,
        height: height,
        fit: width != null && height != null ? BoxFit.fill : fit,
      );
    } else {
      image = Container(
        decoration: BoxDecoration(
          color: Colors.black26.withOpacity(0.1),
          border: Border.all(color: Colors.black.withOpacity(0.2), width: 0.3),
        ),
        child: Image(
          image: const AssetImage(defIcon),
          width: width! - 1,
          height: height! - 1,
          fit: width != null && height != null ? BoxFit.fill : fit,
        ),
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
