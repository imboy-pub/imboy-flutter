import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/page/group_launch/group_launch_view.dart';

class ChatMamBer extends StatefulWidget {
  final dynamic model;

  ChatMamBer({this.model});

  @override
  _ChatMamBerState createState() => _ChatMamBerState();
}

class _ChatMamBerState extends State<ChatMamBer> {
  @override
  Widget build(BuildContext context) {
    String face = widget.model?.avatar;
    String name = widget.model?.nickname;
    String account = widget.model?.account;

    List<Widget> wrap = [];

    wrap.add(
      Wrap(
        spacing: (Get.width - 315) / 5,
        runSpacing: 10.0,
        children: [0].map((item) {
          return InkWell(
            child: Container(
              width: 55.0,
              child: Column(
                children: <Widget>[
                  ImageView(
                    img: strNoEmpty(face) ? face : defIcon,
                    width: 55.0,
                    height: 55.0,
                    fit: BoxFit.cover,
                  ),
                  Space(height: mainSpace / 2),
                  Text(
                    strNoEmpty(name) ? name : '无名氏',
                    style: TextStyle(color: AppColors.MainTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            onTap: () => Get.to(ContactDetailPage(
              id: widget.model.identifier,
              nickname: name,
              account: account,
              avatar: face,
            )),
          );
        }).toList(),
      ),
    );

    wrap.add(
      InkWell(
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
            color: AppColors.LineColor,
            width: 0.2,
          )),
          child: const Image(
            image: AssetImage('assets/images/chat/ic_details_add.png'),
            width: 55.0,
            height: 55.0,
            fit: BoxFit.cover,
          ),
        ),
        onTap: () => Get.to(GroupLaunchPage()),
      ),
    );

    return Container(
      color: Colors.white,
      width: Get.width,
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Wrap(
        spacing: (Get.width - 315) / 5,
        runSpacing: 10.0,
        children: wrap,
      ),
    );
  }
}
