import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/message/content_msg.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/win_media.dart';

class ConversationView extends StatefulWidget {
  final String imageUrl;
  final String title;
  final dynamic payload;
  final Widget time;
  final bool isBorder;

  ConversationView({
    this.imageUrl,
    this.title,
    this.payload,
    this.time,
    this.isBorder = true,
  });

  @override
  _ConversationViewState createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  @override
  Widget build(BuildContext context) {
    var row = new Row(
      children: <Widget>[
        new Space(width: mainSpace),
        new Expanded(
          child: new Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              new Text(
                widget.title ?? '',
                style: TextStyle(fontSize: 17.0, fontWeight: FontWeight.normal),
              ),
              new SizedBox(height: 2.0),
              new ContentMsg(widget?.payload),
            ],
          ),
        ),
        new Space(width: mainSpace),
        new Column(
          children: [
            widget.time,
            new Icon(Icons.flag, color: Colors.transparent),
          ],
        )
      ],
    );

    return new Container(
      padding: EdgeInsets.only(left: 18.0),
      color: Colors.white,
      child: new Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          new ImageView(
            img: widget.imageUrl,
            height: 50.0,
            width: 50.0,
            fit: BoxFit.cover,
          ),
          new Container(
            padding: EdgeInsets.only(right: 18.0, top: 12.0, bottom: 12.0),
            width: winWidth(context) - 68,
            decoration: BoxDecoration(
              border: widget.isBorder
                  ? Border(
                      top: BorderSide(color: lineColor, width: 0.2),
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
