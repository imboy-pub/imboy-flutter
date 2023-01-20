import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact_detail_view.dart';
import 'package:imboy/page/group_launch/group_launch_view.dart';

class ChatMamBer extends StatefulWidget {
  final dynamic model;

  const ChatMamBer({Key? key, this.model}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ChatMamBerState createState() => _ChatMamBerState();
}

class _ChatMamBerState extends State<ChatMamBer> {
  @override
  Widget build(BuildContext context) {
    String face = widget.model?.avatar;
    String name = widget.model?.nickname;
    // String account = widget.model?.account;
    // String sign = widget.model?.sign;

    List<Widget> wrap = [];

    wrap.add(
      Wrap(
        spacing: (Get.width - 315) / 5,
        runSpacing: 10.0,
        children: [0].map((item) {
          return InkWell(
            child: SizedBox(
              width: 55.0,
              child: Column(
                children: <Widget>[
                  ImageView(
                    img: strNoEmpty(face) ? face : defAvatar,
                    width: 55.0,
                    height: 55.0,
                    fit: BoxFit.cover,
                  ),
                  const Space(height: mainSpace / 2),
                  Text(
                    strNoEmpty(name) ? name : '无名氏'.tr,
                    style: const TextStyle(color: AppColors.MainTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            onTap: () =>
                Get.to(() => ContactDetailPage(id: widget.model.identifier)),
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
        onTap: () => Get.to(() => GroupLaunchPage()),
      ),
    );

    return Container(
      color: Colors.white,
      width: Get.width,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      child: Wrap(
        spacing: (Get.width - 315) / 5,
        runSpacing: 10.0,
        children: wrap,
      ),
    );
  }
}
