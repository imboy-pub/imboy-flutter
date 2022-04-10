import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';

class Avatar extends StatelessWidget {
  Avatar({
    Key? key,
    required this.imgUri,
    Function()? this.onTap,
    double? this.width,
    double? this.height,
    String? this.title,
  });

  final String imgUri;
  final void Function()? onTap;
  final double? width;
  final double? height;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: this.onTap ?? null,
      child: Container(
        width: this.width ?? 49,
        height: this.height ?? 49,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            width: 1,
            style: BorderStyle.solid,
            color: Color(0xFFE5E5E5),
          ),
          color: Color(0xFFE5E5E5),
          image: DecorationImage(
            image: isNetWorkImg(this.imgUri)
                ? CachedNetworkImageProvider(this.imgUri)
                : AssetImage(this.imgUri) as ImageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
