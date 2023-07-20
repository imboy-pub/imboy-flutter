import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';

class Avatar extends StatelessWidget {
  const Avatar({
    Key? key,
    required this.imgUri,
    this.onTap,
    this.width,
    this.height,
    this.title,
  }) : super(key: key);

  final String imgUri;
  final void Function()? onTap;
  final double? width;
  final double? height;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width ?? 49,
        height: height ?? 49,
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            width: 0.5,
            style: BorderStyle.solid,
            color: Colors.grey.withOpacity(0.25),
          ),
          color: Colors.grey.withOpacity(0.25),
          image: dynamicAvatar(imgUri),
        ),
      ),
    );
  }
}
