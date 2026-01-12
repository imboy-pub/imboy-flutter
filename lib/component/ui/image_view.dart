import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/i18n/strings.g.dart';

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
      final double targetWidth = width ?? Get.width;
      image = Image(
        image: cachedImageProvider(
          uri,
          w: targetWidth,
        ),
        width: width,
        height: height,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4.0),
            color: Colors.black26.withValues(alpha: 0.1),
          ),
          child: const Icon(Icons.error),
        ),
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
          color: Colors.black26.withValues(alpha: 0.1),
        ),
        child: Text(t.noData),
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
