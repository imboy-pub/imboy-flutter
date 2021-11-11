import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/message/content_msg.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/win_media.dart';

class ConversationView extends StatefulWidget {
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
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
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
                widget.title ?? '',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.normal),
              ),
              SizedBox(height: 2.0),
              ContentMsg(widget.payload),
            ],
          ),
        ),
        Space(width: mainSpace),
        Column(
          children: [
            widget.time!,
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
            showBadge:
                (widget.remindCounter != null && widget.remindCounter! > 0
                    ? true
                    : false),
            shape: BadgeShape.square,
            borderRadius: BorderRadius.circular(10),
            padding: EdgeInsets.fromLTRB(5, 3, 5, 3),
            animationDuration: Duration(milliseconds: 500),
            animationType: BadgeAnimationType.scale,
            badgeContent: Text(
              // _counter.toString(),
              widget.remindCounter != null
                  ? widget.remindCounter!.toString()
                  : "0",
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
              ),
            ),
            child: ImageView(
              img: widget.imageUrl!,
              height: 50.0,
              width: 50.0,
              fit: BoxFit.cover,
            ),
          ),
          Container(
            padding: EdgeInsets.only(right: 18.0, top: 12.0, bottom: 12.0),
            width: winWidth(context) - 68,
            decoration: BoxDecoration(
              border: widget.isBorder
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
