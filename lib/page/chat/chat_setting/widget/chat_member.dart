import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:niku/namespace.dart' as n;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact/contact_detail_view.dart';
import 'package:imboy/page/group_launch/group_launch_view.dart';

class ChatMember extends StatelessWidget {
  final Map<String, dynamic> options;

  const ChatMember({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String face = options['avatar'] ?? '';
    String name = options['nickname'] ?? '';
    // String account = widget.model?.account;
    // String sign = widget.model?.sign;

    List<Widget> wrap = [];

    wrap.add(
      Wrap(
        spacing: (Get.width - 315) / 5,
        runSpacing: 10.0,
        children: [0].map((item) {
          return n.Column(
            [
              n.Row([
                InkWell(
                  onTap: () => Get.to(
                    ContactDetailPage(id: options['peerId'] ?? ''),
                    transition: Transition.rightToLeft,
                    popGesture: true, // 右滑，返回上一页
                  ),
                  child: Avatar(imgUri: face, width: 55, height: 55),
                ),
                n.Padding(
                  left: 20,
                  child: InkWell(
                    child: DottedBorder(
                      borderType: BorderType.RRect,
                      radius: const Radius.circular(4),
                      strokeWidth: 1,
                      dashPattern: const <double>[8, 2],
                      color: AppColors.tabBarElement,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(
                          Icons.add,
                          size: 28,
                          color: AppColors.tabBarElement,
                        ),
                      ),
                    ),
                    onTap: () {
                      // 发起群聊 TODO
                      Get.to(
                        GroupLaunchPage(),
                        transition: Transition.rightToLeft,
                        popGesture: true, // 右滑，返回上一页
                      );
                    },
                  ),
                )
              ]),
              const Space(height: mainSpace / 2),
              n.Row([
                Expanded(
                  child: Text(
                    strNoEmpty(name) ? name : '无名氏'.tr,
                    // '擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦擦',
                    maxLines: 2,
                    style: const TextStyle(color: AppColors.MainTextColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ],
          );
        }).toList(),
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
