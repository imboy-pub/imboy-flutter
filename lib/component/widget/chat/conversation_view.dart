import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/message/content_msg.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';

class ConversationView extends StatelessWidget {
  final String? imageUrl;
  final String? title;
  final dynamic payload;
  final Widget? time;
  final bool isBorder;
  final int? remindCounter;

  ConversationView({
    this.imageUrl,
    this.title,
    this.payload,
    this.time,
    this.isBorder = true,
    this.remindCounter = 0,
  });

  @override
  Widget build(BuildContext context) {
    var row = Row(
      children: <Widget>[
        Space(width: mainSpace),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                this.title ?? '',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.normal),
              ),
              SizedBox(height: 2.0),
              ContentMsg(this.payload),
            ],
          ),
        ),
        Space(width: mainSpace),
        Column(
          children: [
            this.time!,
            Icon(Icons.flag, color: Colors.transparent),
          ],
        )
      ],
    );

    return Container(
      padding: EdgeInsets.only(left: 18.0),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Badge(
            position: BadgePosition.topEnd(top: -4, end: -4),
            showBadge: (this.remindCounter != null && this.remindCounter! > 0
                ? true
                : false),
            shape: BadgeShape.square,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.fromLTRB(5, 3, 5, 3),
            animationDuration: Duration(milliseconds: 500),
            animationType: BadgeAnimationType.scale,
            badgeContent: Text(
              // _counter.toString(),
              this.remindCounter != null ? this.remindCounter!.toString() : "0",
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
              ),
            ),
            child: ImageView(
              img: this.imageUrl!,
              height: 50.0,
              width: 50.0,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: EdgeInsets.only(right: 18.0, top: 12.0, bottom: 12.0),
            width: Get.width - 68,
            decoration: BoxDecoration(
              border: this.isBorder
                  ? Border(
                      top: BorderSide(color: AppColors.LineColor, width: 0.2),
                    )
                  : null,
            ),
            child: row,
          )
        ],
      ),
    );
  }
}
