import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/message/msg_avatar.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:photo_view/photo_view.dart';

class ImgMsg extends StatelessWidget {
  final msg;

  final MessageModel model;

  ImgMsg(this.msg, this.model);

  @override
  Widget build(BuildContext context) {
    if (!listNoEmpty(msg['imageList'])) return Text('发送中');
    var msgInfo = msg['imageList'][1];
    var _height = msgInfo['height'].toDouble();
    var resultH = _height > 200.0 ? 200.0 : _height;
    var url = msgInfo['url'];
    var isFile = File(url).existsSync();
    debugPrint(">>>>>>>>>>>>>>>>>>> on context ${context}");
    // final global = Provider.of<GlobalModel>(context, listen: false);
    var body = [
      new MsgAvatar(model: model),
      new Space(width: mainSpace),
      new Expanded(
        child: new GestureDetector(
          child: new Container(
            padding: EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            child: new ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
              child: isFile
                  ? new Image.file(File(url))
                  : new CachedNetworkImage(
                      imageUrl: url, height: resultH, fit: BoxFit.cover),
            ),
          ),
          onTap: () => Get.to(
            PhotoView(
              imageProvider: isFile
                  ? FileImage(File(url)) as ImageProvider
                  : NetworkImage(url) as ImageProvider,
              onTapUp: (c, f, s) => Navigator.of(context).pop(),
              maxScale: 3.0,
              minScale: 1.0,
            ),
          ),
        ),
      ),
      new Spacer(),
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.0),
      child: new Row(children: body),
    );
  }
}
