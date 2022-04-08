import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';

import 'content_msg.dart';

class ConversationView extends StatelessWidget {
  final String? imageUrl;
  final String? title;
  final dynamic payload;
  final Widget? time;
  final bool isBorder;
  final int? remindCounter;
  final int? status; // lastMsgStatus

  ConversationView({
    this.imageUrl,
    this.title,
    this.payload,
    this.time,
    this.isBorder = true,
    this.remindCounter = 0,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    var icon = <Widget>[];
    if (this.status == 10) {
      icon.add(
        Padding(
          padding: EdgeInsets.only(right: 4),
          child: Image(
            image: AssetImage('assets/images/conversation/sending.png'),
            width: 15,
            height: 14,
            fit: BoxFit.fill,
          ),
        ),
      );
    }
    // debugPrint(">>> on this.imageUrl ${this.imageUrl!}");
    return Container(
      padding: EdgeInsets.only(left: 10.0, right: 10),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 49,
            height: 49,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4.0),
              color: Color(0xFFE5E5E5),
              image: DecorationImage(
                image: isNetWorkImg(this.imageUrl!)
                    ? CachedNetworkImageProvider(this.imageUrl!)
                    : AssetImage(this.imageUrl!) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.only(right: 0, top: 10.0, bottom: 12.0),
            width: Get.width - 69,
            decoration: BoxDecoration(
              border: this.isBorder
                  ? Border(
                      top: BorderSide(color: AppColors.LineColor, width: 0.2),
                    )
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Space(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: [
                          Text(
                            this.title ?? '',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Column(
                              children: icon,
                            ),
                            Expanded(child: ContentMsg(this.payload)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Space(width: mainSpace),
                Column(
                  children: [
                    this.time!,
                    Icon(Icons.flag, color: Colors.transparent),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
