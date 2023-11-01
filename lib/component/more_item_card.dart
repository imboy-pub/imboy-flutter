import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';

class MoreItemCard extends StatelessWidget {
  final String? name, icon;
  final VoidCallback? onPressed;
  final double? keyboardHeight;

  const MoreItemCard({
    super.key,
    this.name,
    this.icon,
    this.onPressed,
    this.keyboardHeight,
  });

  @override
  Widget build(BuildContext context) {
    double margin = keyboardHeight != 0.0 ? keyboardHeight! : 0.0;
    double top = margin != 0.0 ? margin / 10 : 20.0;

    return Container(
      padding: EdgeInsets.only(top: top, bottom: 5.0),
      width: (Get.width - 70) / 4,
      child: Column(
        children: <Widget>[
          Container(
            width: 50,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.circular(10.0),
              ),
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
              ),
              onPressed: () {
                if (onPressed != null) {
                  onPressed!();
                }
              },
              // shape: RoundedRectangleBorder(
              //   borderRadius: BorderRadius.all(
              //     Radius.circular(10.0),
              //   ),
              // ),
              child: SizedBox(
                width: 50.0,
                child: Image(image: AssetImage(icon!), fit: BoxFit.cover),
              ),
            ),
          ),
          const Space(width: mainSpace / 2),
          Text(
            name ?? '',
            style:
                const TextStyle(color: AppColors.MainTextColor, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
