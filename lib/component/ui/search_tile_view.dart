import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

class SearchTileView extends StatelessWidget {
  final String? text;
  final int? type;
  final VoidCallback? onPressed;

  const SearchTileView(
    this.text, {
    super.key,
    this.type = 0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    var bt = TextButton(
      onPressed: onPressed ?? () {},
      child: Row(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Icon(
              Icons.map,
              color: Colors.green,
              size: 50.0,
            ),
          ),
          const Text('搜索：'),
          Text(
            text!,
            style: const TextStyle(color: Colors.green),
          ),
        ],
      ),
    );

    var row = Row(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(Icons.map, color: Colors.green, size: 50.0),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                const Text('搜一搜：'),
                Text(
                  text!,
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
            const Text(
              '小程序、公众号、文章、朋友圈、和表情等',
              style: TextStyle(color: AppColors.MainTextColor),
            )
          ],
        )
      ],
    );

    if (type == 0) {
      return Container(
        decoration: BoxDecoration(
            color: strNoEmpty(text) ? Colors.white : AppColors.AppBarColor,
            border: Border(
                top: BorderSide(
                    color: Colors.grey.withOpacity(0.2), width: 0.5))),
        width: Get.width,
        height: 65.0,
        child: strNoEmpty(text) ? bt : Container(),
      );
    } else {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.withOpacity(0.2), width: 0.5),
          ),
        ),
        width: Get.width,
        height: 65.0,
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15.0),
            backgroundColor: Colors.white,
          ),
          onPressed: () {},
          child: row,
        ),
      );
    }
  }
}
